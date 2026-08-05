import Foundation
import Observation

enum AppContentState: Equatable {
    case loading
    case needsPermission
    case permissionDenied
    case noContacts
    case allExcluded
    case ready
    case failed
}

struct ExcludedPerson: Identifiable, Equatable {
    let id: String
    let displayName: String
}

struct ContactInsight: Identifiable, Equatable {
    let contact: CallableContact
    let openedAt: [Date]
    let isExcluded: Bool

    var id: String { contact.id }
    var callOpenCount: Int { openedAt.count }
    var lastOpenedAt: Date? { openedAt.max() }
}

@MainActor
@Observable
final class AppModel {
    private let contactsProvider: any ContactProviding
    private let callOpener: any CallOpening
    private let history: LocalHistoryStore
    private let suggestionEngine: SuggestionEngine
    private let now: () -> Date
    private let randomUnit: () -> Double

    private(set) var state: AppContentState = .loading
    private(set) var accessState: ContactAccessState = .notDetermined
    private(set) var currentSuggestion: CallableContact?
    private(set) var summary: ActivitySummary = .empty
    private(set) var excludedPeople: [ExcludedPerson] = []
    private(set) var contactInsights: [ContactInsight] = []
    private(set) var contactCount = 0
    var errorMessage: String?

    private var allContacts: [CallableContact] = []
    private var sessionSkippedContactIDs: Set<String> = []

    init(
        contacts: any ContactProviding,
        callOpener: any CallOpening,
        history: LocalHistoryStore,
        suggestionEngine: SuggestionEngine? = nil,
        now: @escaping () -> Date = { .now },
        randomUnit: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.contactsProvider = contacts
        self.callOpener = callOpener
        self.history = history
        self.suggestionEngine = suggestionEngine ?? SuggestionEngine()
        self.now = now
        self.randomUnit = randomUnit
    }

    func refresh() async {
        state = .loading
        errorMessage = nil
        accessState = contactsProvider.accessState

        guard accessState == .authorized || accessState == .limited else {
            allContacts = []
            contactCount = 0
            state = accessState == .notDetermined ? .needsPermission : .permissionDenied
            refreshLocalData()
            return
        }

        do {
            allContacts = try contactsProvider.callableContacts()
            contactCount = allContacts.count
            try refreshLocalDataThrowing()
            updateContentState()
        } catch {
            errorMessage = "InTouch couldn’t load your contacts. Please try again."
            state = .failed
        }
    }

    func requestContactsAccess() async {
        accessState = await contactsProvider.requestAccess()
        await refresh()
    }

    func requestSuggestion() {
        sessionSkippedContactIDs.removeAll()
        chooseSuggestion()
    }

    func skipCurrentSuggestion() {
        guard let suggestion = currentSuggestion else { return }
        sessionSkippedContactIDs.insert(suggestion.id)
        currentSuggestion = nil
        chooseSuggestion()
    }

    private func chooseSuggestion() {
        errorMessage = nil
        do {
            let permanentlyExcludedIDs = try history.excludedContactIDs()
            let activity = try history.activity()
            currentSuggestion = suggestionEngine.suggest(
                from: allContacts,
                excludedContactIDs: permanentlyExcludedIDs.union(sessionSkippedContactIDs),
                activity: activity,
                now: now(),
                randomUnit: randomUnit()
            )

            if currentSuggestion == nil, !sessionSkippedContactIDs.isEmpty {
                sessionSkippedContactIDs.removeAll()
                currentSuggestion = suggestionEngine.suggest(
                    from: allContacts,
                    excludedContactIDs: permanentlyExcludedIDs,
                    activity: activity,
                    now: now(),
                    randomUnit: randomUnit()
                )
            }

            if currentSuggestion == nil {
                updateContentState()
            }
        } catch {
            errorMessage = "InTouch couldn’t choose someone right now. Please try again."
            state = .failed
        }
    }

    func callCurrentSuggestion() async {
        guard let suggestion = currentSuggestion else { return }
        errorMessage = nil

        guard await callOpener.openCall(to: suggestion.phoneNumber) else {
            errorMessage = "The calling screen couldn’t be opened on this device."
            return
        }

        do {
            try history.recordHandoff(for: suggestion, at: now())
            try refreshLocalDataThrowing()
            currentSuggestion = nil
            sessionSkippedContactIDs.removeAll()
        } catch {
            errorMessage = "The calling screen opened, but InTouch couldn’t update your activity."
            currentSuggestion = nil
        }
    }

    func rejectCurrentSuggestion() {
        guard let suggestion = currentSuggestion else { return }
        errorMessage = nil
        do {
            try history.exclude(
                contactID: suggestion.id,
                phoneNumber: suggestion.phoneNumber,
                at: now()
            )
            try refreshLocalDataThrowing()
            currentSuggestion = nil
            updateContentState()
            if state == .ready {
                chooseSuggestion()
            }
        } catch {
            errorMessage = "InTouch couldn’t remember that choice. Please try again."
        }
    }

    func restore(contactID: String) {
        do {
            try history.restore(contactID: contactID)
            try refreshLocalDataThrowing()
            updateContentState()
        } catch {
            errorMessage = "That person couldn’t be restored. Please try again."
        }
    }

    func markNotInterested(contactID: String) {
        guard let contact = allContacts.first(where: { $0.id == contactID }) else { return }
        errorMessage = nil
        do {
            try history.exclude(
                contactID: contact.id,
                phoneNumber: contact.phoneNumber,
                at: now()
            )
            if currentSuggestion?.id == contactID {
                currentSuggestion = nil
            }
            sessionSkippedContactIDs.remove(contactID)
            try refreshLocalDataThrowing()
            updateContentState()
        } catch {
            errorMessage = "InTouch couldn’t remember that choice. Please try again."
        }
    }

    func deleteAllData() {
        do {
            try history.deleteAllData()
            currentSuggestion = nil
            sessionSkippedContactIDs.removeAll()
            try refreshLocalDataThrowing()
            updateContentState()
        } catch {
            errorMessage = "InTouch couldn’t delete its local data. Please try again."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func refreshLocalData() {
        do {
            try refreshLocalDataThrowing()
        } catch {
            summary = .empty
            excludedPeople = []
            contactInsights = []
        }
    }

    private func refreshLocalDataThrowing() throws {
        summary = try history.summary(forMonthContaining: now())
        let nameByID = Dictionary(uniqueKeysWithValues: allContacts.map { ($0.id, $0.displayName) })
        let excludedRecords = try history.excludedRecords()
        excludedPeople = excludedRecords.map { record in
            ExcludedPerson(
                id: record.contactID,
                displayName: nameByID[record.contactID] ?? "Unavailable contact"
            )
        }
        let excludedIDs = Set(excludedRecords.map(\.contactID))
        let activityByContact = Dictionary(grouping: try history.activity(), by: \.contactID)
        contactInsights = allContacts
            .map { contact in
                ContactInsight(
                    contact: contact,
                    openedAt: activityByContact[contact.id, default: []]
                        .map(\.openedAt)
                        .sorted(by: >),
                    isExcluded: excludedIDs.contains(contact.id)
                )
            }
            .sorted {
                $0.contact.displayName.localizedCaseInsensitiveCompare($1.contact.displayName) == .orderedAscending
            }
    }

    private func updateContentState() {
        guard accessState == .authorized || accessState == .limited else {
            state = accessState == .notDetermined ? .needsPermission : .permissionDenied
            return
        }
        guard !allContacts.isEmpty else {
            state = .noContacts
            return
        }

        let excludedIDs = Set(excludedPeople.map(\.id))
        state = allContacts.contains { !excludedIDs.contains($0.id) } ? .ready : .allExcluded
    }
}
