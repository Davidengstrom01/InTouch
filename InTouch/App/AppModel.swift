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
    private(set) var contactCount = 0
    var errorMessage: String?

    private var allContacts: [CallableContact] = []

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
        errorMessage = nil
        do {
            currentSuggestion = suggestionEngine.suggest(
                from: allContacts,
                excludedContactIDs: try history.excludedContactIDs(),
                activity: try history.activity(),
                now: now(),
                randomUnit: randomUnit()
            )
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
            summary = try history.summary(forMonthContaining: now())
            currentSuggestion = nil
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
                requestSuggestion()
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

    func deleteAllData() {
        do {
            try history.deleteAllData()
            currentSuggestion = nil
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
        }
    }

    private func refreshLocalDataThrowing() throws {
        summary = try history.summary(forMonthContaining: now())
        let nameByID = Dictionary(uniqueKeysWithValues: allContacts.map { ($0.id, $0.displayName) })
        excludedPeople = try history.excludedRecords().map { record in
            ExcludedPerson(
                id: record.contactID,
                displayName: nameByID[record.contactID] ?? "Unavailable contact"
            )
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
