import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Why an encrypted backup cannot be sealed or opened. Every failure is final:
/// nothing is returned, so no partial data ever reaches the restore.
public enum BackupEncryptionError: Error, Equatable, Sendable {
    /// The data does not start with `BackupEncryption.magic` (a plain JSON backup).
    case notEncrypted
    /// Shorter than a header and a tag.
    case truncated
    /// Larger than any real backup (`BackupCodec.maxFileSize`) could be once sealed.
    case tooLarge
    /// Made by a newer Luna Mom (or damaged): the format version is unknown.
    case unsupportedVersion(UInt8)
    /// An unknown key derivation, or an iteration count outside the accepted range.
    case unsupportedParameters
    /// AES-GCM authentication failed: a wrong password, or a file changed after it
    /// was sealed. The two cannot be told apart, by design.
    case wrongPassword
    /// Sealing refuses a password `isAcceptable(password:)` rejects.
    case passwordTooShort
    /// The system random generator failed; nothing is sealed without fresh randomness.
    case randomUnavailable
    /// CommonCrypto refused to derive the key.
    case keyDerivationFailed
}

/// What an encrypted file's header says (read without the password).
public struct BackupEncryptionParameters: Equatable, Sendable {
    public var version: UInt8
    public var iterations: Int
    public var salt: Data
    public var nonce: Data
}

/// Password protection for `.lunamom` files (1.1 spec "Encrypted format").
///
/// Layout, all integers big-endian:
///
///     magic "LUNAENC1" (8) · version (1) = 1 · KDF (1) = 1, PBKDF2-HMAC-SHA256 ·
///     iterations (UInt32) · salt (16) · AES-GCM nonce (12) · ciphertext · tag (16)
///
/// The 42-byte header is authenticated as AES-GCM associated data, so changing any
/// byte of it fails like a wrong password. The ciphertext is the plain JSON backup
/// (`BackupCodec`), which still goes through `BackupCodec.decode` after opening.
/// The key is PBKDF2-HMAC-SHA256 (CommonCrypto) of the password in Unicode NFC, so
/// a password typed with decomposed Vietnamese marks opens the file too.
/// Apple crypto only; the password and the derived key are never stored or logged,
/// and the key bytes are wiped as soon as CryptoKit holds the key.
public enum BackupEncryption {
    public static let magic = Data("LUNAENC1".utf8)
    public static let formatVersion: UInt8 = 1
    /// The only key derivation: PBKDF2 with HMAC-SHA256.
    public static let pbkdf2SHA256: UInt8 = 1
    /// OWASP's 2023 recommendation for PBKDF2-HMAC-SHA256.
    public static let defaultIterations = 600_000
    /// Files asking for fewer are refused: they would protect nothing.
    public static let minimumIterations = 100_000
    /// Files asking for more are refused before any work: a damaged or hostile
    /// count must not freeze the phone. Leaves room for later, stronger defaults.
    public static let maximumIterations = 10_000_000
    public static let saltLength = 16
    public static let nonceLength = 12
    public static let tagLength = 16
    public static let keyLength = 32
    public static let headerLength = 8 + 1 + 1 + 4 + 16 + 12
    public static let minimumPasswordLength = 6

    /// At least `minimumPasswordLength` characters, and not only spaces.
    public static func isAcceptable(password: String) -> Bool {
        password.count >= minimumPasswordLength && !password.allSatisfy(\.isWhitespace)
    }

    /// Whether `data` is an encrypted backup (by its magic header); plain files are JSON.
    public static func isEncrypted(_ data: Data) -> Bool {
        data.count >= magic.count && data.prefix(magic.count).elementsEqual(magic)
    }

    /// Encrypts the plain backup bytes with a fresh random salt and nonce.
    public static func seal(_ plaintext: Data, password: String, iterations: Int = defaultIterations) throws -> Data {
        guard isAcceptable(password: password) else { throw BackupEncryptionError.passwordTooShort }
        guard (minimumIterations...maximumIterations).contains(iterations) else {
            throw BackupEncryptionError.unsupportedParameters
        }
        let salt = try randomBytes(saltLength)
        let nonceBytes = try randomBytes(nonceLength)
        var header = magic
        header.append(formatVersion)
        header.append(pbkdf2SHA256)
        withUnsafeBytes(of: UInt32(iterations).bigEndian) { header.append(contentsOf: $0) }
        header.append(salt)
        header.append(nonceBytes)
        assert(header.count == headerLength)

        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let box = try AES.GCM.seal(plaintext, using: key, nonce: AES.GCM.Nonce(data: nonceBytes), authenticating: header)
        return header + box.ciphertext + box.tag
    }

    /// The plain backup bytes, or an error; never anything in between.
    public static func open(_ data: Data, password: String) throws -> Data {
        let data = Data(data) // Indices from 0 even for a slice.
        let parameters = try parameters(of: data)
        // No file is sealed with an empty password; CommonCrypto would refuse it anyway.
        guard !password.isEmpty else { throw BackupEncryptionError.wrongPassword }
        let header = data.prefix(headerLength)
        let ciphertext = data.subdata(in: headerLength..<data.count - tagLength)
        let tag = data.subdata(in: data.count - tagLength..<data.count)
        let key = try deriveKey(password: password, salt: parameters.salt, iterations: parameters.iterations)
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: parameters.nonce), ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(box, using: key, authenticating: header)
        } catch {
            // Authentication failure, or any other refusal: fail closed, return nothing.
            throw BackupEncryptionError.wrongPassword
        }
    }

    /// Reads and checks the header without the password.
    public static func parameters(of data: Data) throws -> BackupEncryptionParameters {
        let data = Data(data)
        guard isEncrypted(data) else { throw BackupEncryptionError.notEncrypted }
        guard data.count <= BackupCodec.maxFileSize + headerLength + tagLength else { throw BackupEncryptionError.tooLarge }
        guard data.count >= headerLength + tagLength else { throw BackupEncryptionError.truncated }
        var offset = magic.count
        let version = data[offset]
        guard version == formatVersion else { throw BackupEncryptionError.unsupportedVersion(version) }
        offset += 1
        guard data[offset] == pbkdf2SHA256 else { throw BackupEncryptionError.unsupportedParameters }
        offset += 1
        let iterations = data[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
        guard (minimumIterations...maximumIterations).contains(iterations) else {
            throw BackupEncryptionError.unsupportedParameters
        }
        offset += 4
        let salt = data.subdata(in: offset..<offset + saltLength)
        offset += saltLength
        let nonce = data.subdata(in: offset..<offset + nonceLength)
        return BackupEncryptionParameters(version: version, iterations: iterations, salt: salt, nonce: nonce)
    }

    // MARK: - Primitives

    static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        var passwordBytes = Array(password.precomposedStringWithCanonicalMapping.utf8)
        var derived = [UInt8](repeating: 0, count: keyLength)
        defer {
            wipe(&passwordBytes)
            wipe(&derived)
        }
        let status = passwordBytes.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                passwordBuffer.withMemoryRebound(to: CChar.self) { passwordChars in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordChars.baseAddress, passwordChars.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress, saltBuffer.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        &derived, derived.count
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw BackupEncryptionError.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }

    private static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw BackupEncryptionError.randomUnavailable }
        return Data(bytes)
    }

    /// Zeroes a buffer in a way the optimizer keeps (`memset_s`).
    private static func wipe(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = memset_s(base, buffer.count, 0, buffer.count)
        }
    }
}
