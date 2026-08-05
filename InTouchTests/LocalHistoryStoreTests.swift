import Foundation
import SwiftData
import Testing
@testable import InTouch

@MainActor
struct LocalHistoryStoreTests {
    @Test("A rejected contact stays excluded until the user undoes it")
    func exclusionCanBeUndone() throws {
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = LocalHistoryStore(context: container.mainContext)

        try store.exclude(contactID: "alex", phoneNumber: "+46 70 123 45 67")
        #expect(try store.excludedContactIDs() == ["alex"])

        try store.restore(contactID: "alex")
        #expect(try store.excludedContactIDs().isEmpty)
    }

    @Test("Monthly activity counts handoffs and unique people in that month only")
    func monthlyActivitySummary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = LocalHistoryStore(context: container.mainContext)
        let alex = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46700000001")
        let sam = CallableContact(id: "sam", displayName: "Sam", phoneNumber: "+46700000002")

        try store.recordHandoff(for: alex, at: august)
        try store.recordHandoff(for: alex, at: august.addingTimeInterval(60))
        try store.recordHandoff(for: sam, at: august.addingTimeInterval(120))
        try store.recordHandoff(for: sam, at: july)

        #expect(try store.summary(forMonthContaining: august, calendar: calendar) == ActivitySummary(callsOpened: 3, uniquePeople: 2))
    }

    @Test("Delete all removes exclusions and calling activity")
    func deleteAllRemovesLocalData() throws {
        let container = try ModelContainer(
            for: ExcludedContactRecord.self, CallHandoffRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = LocalHistoryStore(context: container.mainContext)
        let contact = CallableContact(id: "alex", displayName: "Alex", phoneNumber: "+46700000001")
        try store.exclude(contactID: contact.id, phoneNumber: contact.phoneNumber)
        try store.recordHandoff(for: contact)

        try store.deleteAllData()

        #expect(try store.excludedContactIDs().isEmpty)
        #expect(try store.summary() == .empty)
    }
}
