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
