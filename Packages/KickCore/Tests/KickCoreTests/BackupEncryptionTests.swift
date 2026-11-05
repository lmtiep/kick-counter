import CryptoKit
import Foundation
import Testing
@testable import KickCore

/// 1.1 spec "Encrypted format": password-protected `.lunamom` files.
struct BackupEncryptionTests {
    private let password = "mẹ-bầu-2026"
    /// The fewest iterations a file may use, so most tests stay fast.
    private let fast = BackupEncryption.minimumIterations

    private var plain: Data {
        get throws { try BackupCodec.encode(BackupFixtureTests.fixture()) }
    }

    // MARK: - Round trip

    @Test func roundTripWithTheDefaultIterationsGivesBackTheSameBytes() throws {
        let json = try plain
        let sealed = try BackupEncryption.seal(json, password: password)
        #expect(BackupEncryption.isEncrypted(sealed))
        #expect(try BackupEncryption.open(sealed, password: password) == json)
        #expect(try BackupEncryption.parameters(of: sealed).iterations == 600_000)
    }

    @Test func theDecryptedBytesDecodeToTheSameDocument() throws {
        let sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        let opened = try BackupEncryption.open(sealed, password: password)
        #expect(try BackupCodec.decode(opened) == BackupFixtureTests.fixture())
    }

    @Test func theSealedFileHoldsNoPlainText() throws {
        let json = try plain
        let sealed = try BackupEncryption.seal(json, password: password, iterations: fast)
        let text = String(decoding: sealed, as: UTF8.self)
        #expect(!text.contains("luna-mom-backup"))
        #expect(!text.contains("Siêu âm"))
        #expect(sealed.count == BackupEncryption.headerLength + json.count + BackupEncryption.tagLength)
    }

    @Test func twoSealsOfTheSameDataDifferBySaltAndNonce() throws {
        let json = try plain
        let first = try BackupEncryption.seal(json, password: password, iterations: fast)
        let second = try BackupEncryption.seal(json, password: password, iterations: fast)
        #expect(first != second)
        #expect(try BackupEncryption.parameters(of: first).salt != BackupEncryption.parameters(of: second).salt)
        #expect(try BackupEncryption.parameters(of: first).nonce != BackupEncryption.parameters(of: second).nonce)
    }

    /// A password typed with decomposed Vietnamese marks (another keyboard) still opens it.
    @Test func thePasswordIsComparedInItsComposedForm() throws {
        let composed = "Mẹ yêu con"
        let decomposed = composed.decomposedStringWithCanonicalMapping
        #expect(Array(composed.utf8) != Array(decomposed.utf8))
        let sealed = try BackupEncryption.seal(try plain, password: composed, iterations: fast)
        #expect(try BackupEncryption.open(sealed, password: decomposed) == (try plain))
    }

    // MARK: - Wrong password and damage: fail closed, no data

    @Test func aWrongPasswordFailsWithWrongPassword() throws {
        let sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        #expect(throws: BackupEncryptionError.wrongPassword) {
            try BackupEncryption.open(sealed, password: "mẹ-bầu-2025")
        }
        #expect(throws: BackupEncryptionError.wrongPassword) {
            try BackupEncryption.open(sealed, password: "")
        }
    }

    @Test func everyTamperedByteAfterTheMagicFails() throws {
        let sealed = try BackupEncryption.seal(Data("{\"a\":1}".utf8), password: password, iterations: fast)
        // Every byte from the version on: header (authenticated), ciphertext and tag.
        for index in BackupEncryption.magic.count..<sealed.count {
            var tampered = sealed
            tampered[index] ^= 0x01
            #expect(throws: BackupEncryptionError.self, "byte \(index)") {
                try BackupEncryption.open(tampered, password: password)
            }
        }
    }

    @Test func aTamperedCiphertextByteIsAnAuthenticationFailure() throws {
        var sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        sealed[BackupEncryption.headerLength + 3] ^= 0x80
        #expect(throws: BackupEncryptionError.wrongPassword) {
            try BackupEncryption.open(sealed, password: password)
        }
    }

    /// The header is authenticated: the same key, nonce and plaintext sealed without
    /// it as associated data do not open.
    @Test func theHeaderIsAuthenticatedData() throws {
        let sealed = try BackupEncryption.seal(Data("{\"a\":1}".utf8), password: password, iterations: fast)
        let parameters = try BackupEncryption.parameters(of: sealed)
        let key = try BackupEncryption.deriveKey(password: password, salt: parameters.salt, iterations: parameters.iterations)
        let box = try AES.GCM.seal(Data("{\"a\":1}".utf8), using: key, nonce: AES.GCM.Nonce(data: parameters.nonce))
        let forged = sealed.prefix(BackupEncryption.headerLength) + box.ciphertext + box.tag
        #expect(throws: BackupEncryptionError.wrongPassword) {
            try BackupEncryption.open(forged, password: password)
        }
    }

    @Test func aTruncatedFileFails() throws {
        let sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        for length in [0, 7, 8, 20, BackupEncryption.headerLength, BackupEncryption.headerLength + BackupEncryption.tagLength - 1] {
            #expect(throws: BackupEncryptionError.truncated, "length \(length)") {
                try BackupEncryption.open(Data(sealed.prefix(length)).withMagicIfLong, password: password)
            }
        }
        // Cut inside the ciphertext: long enough to parse, but the tag no longer matches.
        #expect(throws: BackupEncryptionError.wrongPassword) {
            try BackupEncryption.open(Data(sealed.dropLast(1)), password: password)
        }
    }

    @Test func anUnknownVersionFails() throws {
        var sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        sealed[BackupEncryption.magic.count] = 2
        #expect(throws: BackupEncryptionError.unsupportedVersion(2)) {
            try BackupEncryption.open(sealed, password: password)
        }
        sealed[BackupEncryption.magic.count] = 0
        #expect(throws: BackupEncryptionError.unsupportedVersion(0)) {
            try BackupEncryption.open(sealed, password: password)
        }
    }

    @Test func anUnknownKeyDerivationFails() throws {
        var sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        sealed[BackupEncryption.magic.count + 1] = 9
        #expect(throws: BackupEncryptionError.unsupportedParameters) {
            try BackupEncryption.open(sealed, password: password)
        }
    }

    /// A file may ask for more work in a later version, but never an absurd amount
    /// (a hang) nor too little to protect the data.
    @Test func iterationsOutsideTheAcceptedRangeFailBeforeAnyWork() throws {
        var sealed = try BackupEncryption.seal(try plain, password: password, iterations: fast)
        let offset = BackupEncryption.magic.count + 2
        for iterations: UInt32 in [0, 1, UInt32(BackupEncryption.minimumIterations - 1), UInt32(BackupEncryption.maximumIterations + 1), .max] {
            sealed.replaceSubrange(offset..<offset + 4, with: withUnsafeBytes(of: iterations.bigEndian) { Data($0) })
            #expect(throws: BackupEncryptionError.unsupportedParameters, "\(iterations)") {
                try BackupEncryption.open(sealed, password: password)
            }
        }
        #expect(throws: BackupEncryptionError.unsupportedParameters) {
            try BackupEncryption.seal(Data("{}".utf8), password: password, iterations: BackupEncryption.minimumIterations - 1)
        }
    }

    /// Future-proof: the count is read from the file, not assumed.
    @Test func theIterationCountIsReadFromTheFile() throws {
        let json = try plain
        let custom = BackupEncryption.minimumIterations + 12_345
        let sealed = try BackupEncryption.seal(json, password: password, iterations: custom)
        let parameters = try BackupEncryption.parameters(of: sealed)
        #expect(parameters.iterations == custom)
        #expect(parameters.version == 1)
        #expect(try BackupEncryption.open(sealed, password: password) == json)
        // The same password with another count derives another key.
        var other = sealed
        let offset = BackupEncryption.magic.count + 2
        other.replaceSubrange(offset..<offset + 4, with: withUnsafeBytes(of: UInt32(custom + 1).bigEndian) { Data($0) })
        #expect(throws: BackupEncryptionError.wrongPassword) {
            try BackupEncryption.open(other, password: password)
        }
    }

    /// Published PBKDF2-HMAC-SHA256 vectors (RFC 7914 §11 style, P="password", S="salt").
    @Test func keyDerivationMatchesTheKnownAnswers() throws {
        let salt = Data("salt".utf8)
        let vectors: [(Int, String)] = [
            (1, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"),
            (2, "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"),
            (4096, "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"),
        ]
        for (iterations, expected) in vectors {
            let key = try BackupEncryption.deriveKey(password: "password", salt: salt, iterations: iterations)
            let hex = key.withUnsafeBytes { $0.map { String(format: "%02x", $0) }.joined() }
            #expect(hex == expected, "c=\(iterations)")
        }
    }

    @Test func theHeaderLayoutIsStable() throws {
        let sealed = try BackupEncryption.seal(Data("{}".utf8), password: password, iterations: 200_000)
        #expect(Array(sealed.prefix(8)) == Array("LUNAENC1".utf8))
        #expect(sealed[8] == 1) // format version
        #expect(sealed[9] == 1) // PBKDF2-HMAC-SHA256
        #expect(Array(sealed[10..<14]) == [0x00, 0x03, 0x0D, 0x40]) // 200 000, big-endian
        #expect(BackupEncryption.headerLength == 8 + 1 + 1 + 4 + 16 + 12)
    }

    // MARK: - Passwords

    @Test func aShortPasswordIsRefusedWhenSealing() {
        #expect(!BackupEncryption.isAcceptable(password: "12345"))
        #expect(BackupEncryption.isAcceptable(password: "123456"))
        // Counted in characters, not bytes: "mẹbầu1" is six.
        #expect(BackupEncryption.isAcceptable(password: "mẹbầu1"))
        #expect(!BackupEncryption.isAcceptable(password: "      "))
        #expect(throws: BackupEncryptionError.passwordTooShort) {
            try BackupEncryption.seal(Data("{}".utf8), password: "12345", iterations: fast)
        }
    }

    // MARK: - Plain files

    @Test func aPlainFileIsNotEncryptedAndStillDecodes() throws {
        let json = try plain
        #expect(!BackupEncryption.isEncrypted(json))
        #expect(!BackupEncryption.isEncrypted(Data()))
        #expect(!BackupEncryption.isEncrypted(Data("LUNAENC".utf8)))
        #expect(try BackupCodec.decode(json) == BackupFixtureTests.fixture())
        #expect(throws: BackupEncryptionError.notEncrypted) {
            try BackupEncryption.open(json, password: password)
        }
    }

    @Test func anOversizedFileIsRefusedBeforeAnyWork() throws {
        var huge = BackupEncryption.magic
        huge.append(Data(count: BackupCodec.maxFileSize + BackupEncryption.headerLength + BackupEncryption.tagLength + 1))
        #expect(throws: BackupEncryptionError.tooLarge) {
            try BackupEncryption.open(huge, password: password)
        }
    }
}

private extension Data {
    /// Short prefixes keep the magic when they are long enough to hold it, so the
    /// test checks truncation rather than `notEncrypted`.
    var withMagicIfLong: Data {
        count >= BackupEncryption.magic.count ? self : BackupEncryption.magic + self
    }
}
