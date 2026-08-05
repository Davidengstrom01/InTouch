import Foundation
import Testing
@testable import InTouch

@MainActor
struct SuggestionEngineTests {
    @Test("Excluded contacts are never suggested")
    func excludedContactsAreNeverSuggested() {
        let excluded = CallableContact(id: "excluded", displayName: "Alex", phoneNumber: "+46700000001")
        let available = CallableContact(id: "available", displayName: "Sam", phoneNumber: "+46700000002")

        let suggestion = SuggestionEngine().suggest(
            from: [excluded, available],
            excludedContactIDs: [excluded.id],
            activity: [],
            now: Date(timeIntervalSince1970: 1_800_000_000),
            randomUnit: 0
        )

        #expect(suggestion == available)
    }

    @Test("Recently called contacts stay out of suggestions while another person is available")
    func recentlyCalledContactsAreOnCooldown() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recent = CallableContact(id: "recent", displayName: "Alex", phoneNumber: "+46700000001")
        let available = CallableContact(id: "available", displayName: "Sam", phoneNumber: "+46700000002")

        let suggestion = SuggestionEngine().suggest(
            from: [recent, available],
            excludedContactIDs: [],
            activity: [CallActivity(contactID: recent.id, openedAt: now.addingTimeInterval(-.day))],
            now: now,
            randomUnit: 0
        )

        #expect(suggestion == available)
    }

    @Test("Never-called contacts receive a higher exploration weight")
    func neverCalledContactsReceiveHigherWeight() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let called = CallableContact(id: "called", displayName: "Alex", phoneNumber: "+46700000001")
        let neverCalled = CallableContact(id: "new", displayName: "Sam", phoneNumber: "+46700000002")

        let suggestion = SuggestionEngine().suggest(
            from: [called, neverCalled],
            excludedContactIDs: [],
            activity: [CallActivity(contactID: called.id, openedAt: now.addingTimeInterval(-30 * .day))],
            now: now,
            randomUnit: 0.75
        )

        #expect(suggestion == neverCalled)
    }

    @Test("Cooldown is ignored when every available contact is cooling down")
    func cooldownFallsBackToTheAvailablePool() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let alex = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46700000001")
        let sam = CallableContact(id: "sam", displayName: "Sam", phoneNumber: "+46700000002")

        let suggestion = SuggestionEngine().suggest(
            from: [alex, sam],
            excludedContactIDs: [],
            activity: [
                CallActivity(contactID: alex.id, openedAt: now.addingTimeInterval(-.day)),
                CallActivity(contactID: sam.id, openedAt: now.addingTimeInterval(-2 * .day))
            ],
            now: now,
            randomUnit: 0.99
        )

        #expect(suggestion != nil)
    }

    @Test("No suggestion is returned when every contact is excluded")
    func allExcludedReturnsNoSuggestion() {
        let contact = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46700000001")

        let suggestion = SuggestionEngine().suggest(
            from: [contact],
            excludedContactIDs: [contact.id],
            activity: [],
            now: Date(timeIntervalSince1970: 1_800_000_000),
            randomUnit: 0
        )

        #expect(suggestion == nil)
    }
}

private extension TimeInterval {
    static let day: TimeInterval = 24 * 60 * 60
}
