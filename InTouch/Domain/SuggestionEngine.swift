import Foundation

struct CallableContact: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let phoneNumber: String
    let thumbnailData: Data?

    init(
        id: String,
        displayName: String,
        phoneNumber: String,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.thumbnailData = thumbnailData
    }
}

struct CallActivity: Equatable, Sendable {
    let contactID: String
    let openedAt: Date
}

struct SuggestionEngine {
    func suggest(
        from contacts: [CallableContact],
        excludedContactIDs: Set<String>,
        activity: [CallActivity],
        now: Date,
        randomUnit: Double
    ) -> CallableContact? {
        let available = contacts.filter { !excludedContactIDs.contains($0.id) }
        guard !available.isEmpty else { return nil }

        let lastOpenedByContact = Dictionary(
            activity.map { ($0.contactID, $0.openedAt) },
            uniquingKeysWith: max
        )
        let cooldownCutoff = now.addingTimeInterval(-14 * 24 * 60 * 60)
        let outsideCooldown = available.filter { contact in
            guard let lastOpened = lastOpenedByContact[contact.id] else { return true }
            return lastOpened <= cooldownCutoff
        }

        let candidates = outsideCooldown.isEmpty ? available : outsideCooldown
        let weightedCandidates = candidates.map { contact in
            (contact, weight(for: contact, lastOpenedByContact: lastOpenedByContact, now: now))
        }
        let totalWeight = weightedCandidates.reduce(0) { $0 + $1.1 }
        let unit = min(max(randomUnit, 0), 0.999_999_999)
        let target = unit * totalWeight
        var cumulativeWeight = 0.0

        for (contact, weight) in weightedCandidates {
            cumulativeWeight += weight
            if target < cumulativeWeight {
                return contact
            }
        }

        return weightedCandidates.last?.0
    }

    private func weight(
        for contact: CallableContact,
        lastOpenedByContact: [String: Date],
        now: Date
    ) -> Double {
        guard let lastOpened = lastOpenedByContact[contact.id] else { return 2 }
        let daysSinceLastOpen = max(0, now.timeIntervalSince(lastOpened) / (24 * 60 * 60))
        return min(2, max(0.25, daysSinceLastOpen / 30))
    }
}
