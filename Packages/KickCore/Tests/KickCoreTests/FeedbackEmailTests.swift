import Foundation
import Testing
@testable import KickCore

struct FeedbackEmailTests {
    private let email = FeedbackEmail(
        subject: "Luna Mom – góp ý",
        labels: .init(app: "Ứng dụng", ios: "iOS", device: "Thiết bị", language: "Ngôn ngữ", mode: "Chế độ"),
        facts: .init(appVersion: "1.0.0", build: "7", iOSVersion: "26.1", deviceModel: "iPhone17,1", language: "vi", mode: "pregnant")
    )

    @Test func theBodyStartsWithRoomForTheMessageThenHoldsOnlyTheFacts() {
        let lines = email.body.components(separatedBy: "\n")
        #expect(lines.prefix(2) == ["", ""])
        #expect(lines.dropFirst(2).first == "—")
        #expect(lines.dropFirst(3).map { $0 } == [
            "Ứng dụng: 1.0.0 (7)", "iOS: 26.1", "Thiết bị: iPhone17,1", "Ngôn ngữ: vi", "Chế độ: pregnant",
        ])
    }

    @Test func theAddressIsTheSupportMailbox() {
        #expect(FeedbackEmail.address == "lmtiep@gmail.com")
    }

    @Test func mailtoEncodesSubjectAndBody() throws {
        let url = try #require(email.mailtoURL)
        let text = url.absoluteString
        #expect(text.hasPrefix("mailto:lmtiep@gmail.com?subject="))
        #expect(!text.contains(" "))
        #expect(!text.contains("\n"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first { $0.name == "subject" }?.value == "Luna Mom – góp ý")
        #expect(components.queryItems?.first { $0.name == "body" }?.value == email.body)
    }

    @Test func mailtoKeepsReservedCharactersInsideTheValues() throws {
        let tricky = FeedbackEmail(
            subject: "a&b=c",
            labels: .init(app: "A", ios: "I", device: "D", language: "L", mode: "M"),
            facts: .init(appVersion: "1&2", build: "3", iOSVersion: "4", deviceModel: "x?y#z", language: "en", mode: "m")
        )
        let url = try #require(tricky.mailtoURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.count == 2)
        #expect(components.queryItems?.first { $0.name == "subject" }?.value == "a&b=c")
        #expect(components.queryItems?.first { $0.name == "body" }?.value == tricky.body)
    }

    @Test func theSimulatorModelWinsOverTheMachineName() {
        #expect(FeedbackEmail.modelIdentifier(machine: "arm64", simulatorModel: "iPhone17,1") == "iPhone17,1")
        #expect(FeedbackEmail.modelIdentifier(machine: "iPhone16,2", simulatorModel: nil) == "iPhone16,2")
        #expect(FeedbackEmail.modelIdentifier(machine: "iPhone16,2", simulatorModel: "") == "iPhone16,2")
    }

    @Test func theModeSeparatesTrackingFromTryingToConceive() {
        #expect(FeedbackMode(appMode: .pregnant, goal: .tracking) == .pregnant)
        #expect(FeedbackMode(appMode: .partner, goal: .conceiving) == .partner)
        #expect(FeedbackMode(appMode: .tryingToConceive, goal: .tracking) == .cycleTracking)
        #expect(FeedbackMode(appMode: .tryingToConceive, goal: .conceiving) == .tryingToConceive)
    }
}
