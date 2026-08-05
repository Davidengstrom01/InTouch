import Foundation
import SwiftData
import Testing
@testable import InTouch

@MainActor
struct AppModelTests {
    @Test("A failed calling handoff is not recorded as activity")
    func failedCallIsNotRecorded() async throws {
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let history = LocalHistoryStore(context: container.mainContext)
        let contact = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46701234567")
        let model = AppModel(
            contacts: StubContactProvider(contacts: [contact]),
            callOpener: StubCallOpener(result: false),
            history: history,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            randomUnit: { 0 }
        )

        await model.refresh()
        model.requestSuggestion()
        await model.callCurrentSuggestion()

        #expect(model.summary == .empty)
        #expect(model.errorMessage != nil)
    }

    @Test("A successful calling handoff is recorded and clears the suggestion")
    func successfulCallIsRecorded() async throws {
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let history = LocalHistoryStore(context: container.mainContext)
        let contact = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46701234567")
        let model = AppModel(
            contacts: StubContactProvider(contacts: [contact]),
            callOpener: StubCallOpener(result: true),
            history: history,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            randomUnit: { 0 }
        )

        await model.refresh()
        model.requestSuggestion()
        await model.callCurrentSuggestion()

        #expect(model.summary == ActivitySummary(callsOpened: 1, uniquePeople: 1))
        #expect(model.currentSuggestion == nil)
    }

    @Test("Skipping shows someone else without excluding the person")
    func skipIsSessionOnly() async throws {
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let history = LocalHistoryStore(context: container.mainContext)
        let alex = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46701234567")
        let sam = CallableContact(id: "sam", displayName: "Sam", phoneNumber: "+46707654321")
        let model = AppModel(
            contacts: StubContactProvider(contacts: [alex, sam]),
            callOpener: StubCallOpener(result: true),
            history: history,
            randomUnit: { 0 }
        )

        await model.refresh()
        model.requestSuggestion()
        #expect(model.currentSuggestion == alex)

        model.skipCurrentSuggestion()

        #expect(model.currentSuggestion == sam)
        #expect(try history.excludedContactIDs().isEmpty)
    }

    @Test("A contact can be marked not interested directly from the contact list")
    func contactCanBeMarkedNotInterested() async throws {
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let history = LocalHistoryStore(context: container.mainContext)
        let alex = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46701234567")
        let model = AppModel(
            contacts: StubContactProvider(contacts: [alex]),
            callOpener: StubCallOpener(result: true),
            history: history
        )

        await model.refresh()
        model.markNotInterested(contactID: alex.id)

        #expect(model.contactInsights.first?.isExcluded == true)
        #expect(try history.excludedContactIDs() == [alex.id])
        #expect(model.state == .allExcluded)
    }
}

@MainActor
private final class StubContactProvider: ContactProviding {
    let contacts: [CallableContact]

    init(contacts: [CallableContact]) {
        self.contacts = contacts
    }

    var accessState: ContactAccessState { .authorized }
    func requestAccess() async -> ContactAccessState { .authorized }
    func callableContacts() throws -> [CallableContact] { contacts }
}

@MainActor
private struct StubCallOpener: CallOpening {
    let result: Bool
    func openCall(to phoneNumber: String) async -> Bool { result }
}
