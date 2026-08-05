import CryptoKit
import Foundation
import SwiftData

@Model
final class ExcludedContactRecord {
    @Attribute(.unique) var contactID: String
    var phoneFingerprint: String
    var excludedAt: Date

    init(contactID: String, phoneFingerprint: String, excludedAt: Date) {
        self.contactID = contactID
        self.phoneFingerprint = phoneFingerprint
        self.excludedAt = excludedAt
    }
}

@Model
final class CallHandoffRecord {
    var contactID: String
    var phoneFingerprint: String
    var openedAt: Date

    init(contactID: String, phoneFingerprint: String, openedAt: Date) {
        self.contactID = contactID
        self.phoneFingerprint = phoneFingerprint
        self.openedAt = openedAt
    }
}

struct ActivitySummary: Equatable {
    let callsOpened: Int
    let uniquePeople: Int

    static let empty = ActivitySummary(callsOpened: 0, uniquePeople: 0)
}

@MainActor
struct LocalHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func exclude(contactID: String, phoneNumber: String, at date: Date = .now) throws {
        let records = try context.fetch(FetchDescriptor<ExcludedContactRecord>())
        guard !records.contains(where: { $0.contactID == contactID }) else { return }

        context.insert(
            ExcludedContactRecord(
                contactID: contactID,
                phoneFingerprint: PhoneFingerprint.make(from: phoneNumber),
                excludedAt: date
            )
        )
        try context.save()
    }

    func restore(contactID: String) throws {
        let records = try context.fetch(FetchDescriptor<ExcludedContactRecord>())
        records.filter { $0.contactID == contactID }.forEach(context.delete)
        try context.save()
    }

    func excludedContactIDs() throws -> Set<String> {
        Set(try excludedRecords().map(\.contactID))
    }

    func excludedRecords() throws -> [ExcludedContactRecord] {
        var descriptor = FetchDescriptor<ExcludedContactRecord>()
        descriptor.sortBy = [SortDescriptor(\.excludedAt, order: .reverse)]
        return try context.fetch(descriptor)
    }

    func recordHandoff(for contact: CallableContact, at date: Date = .now) throws {
        context.insert(
            CallHandoffRecord(
                contactID: contact.id,
                phoneFingerprint: PhoneFingerprint.make(from: contact.phoneNumber),
                openedAt: date
            )
        )
        try context.save()
    }

    func activity() throws -> [CallActivity] {
        try context.fetch(FetchDescriptor<CallHandoffRecord>()).map {
            CallActivity(contactID: $0.contactID, openedAt: $0.openedAt)
        }
    }

    func summary(forMonthContaining date: Date = .now, calendar: Calendar = .current) throws -> ActivitySummary {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return .empty }
        let records = try context.fetch(FetchDescriptor<CallHandoffRecord>()).filter {
            interval.contains($0.openedAt)
        }
        return ActivitySummary(
            callsOpened: records.count,
            uniquePeople: Set(records.map(\.contactID)).count
        )
    }

    func deleteAllData() throws {
        try context.delete(model: ExcludedContactRecord.self)
        try context.delete(model: CallHandoffRecord.self)
        try context.save()
    }
}

enum PhoneFingerprint {
    static func make(from phoneNumber: String) -> String {
        let normalized = phoneNumber.unicodeScalars.filter {
            CharacterSet.decimalDigits.contains($0) || $0 == "+"
        }
        let digest = SHA256.hash(data: Data(String(String.UnicodeScalarView(normalized)).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
