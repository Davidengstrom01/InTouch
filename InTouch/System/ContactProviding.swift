import Contacts
import Foundation

enum ContactAccessState: Equatable {
    case notDetermined
    case limited
    case authorized
    case denied
}

@MainActor
protocol ContactProviding {
    var accessState: ContactAccessState { get }
    func requestAccess() async -> ContactAccessState
    func callableContacts() throws -> [CallableContact]
}

enum ContactMapper {
    static func callableContact(from contact: CNContact) -> CallableContact? {
        guard contact.contactType == .person else { return nil }
        let displayName = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !displayName.isEmpty, let number = preferredPhoneNumber(from: contact.phoneNumbers) else {
            return nil
        }

        return CallableContact(
            id: contact.identifier,
            displayName: displayName,
            phoneNumber: number,
            thumbnailData: contact.thumbnailImageData
        )
    }

    private static func preferredPhoneNumber(
        from phoneNumbers: [CNLabeledValue<CNPhoneNumber>]
    ) -> String? {
        let preferredLabels = [CNLabelPhoneNumberiPhone, CNLabelPhoneNumberMobile]
        let preferred = phoneNumbers.first { value in
            guard let label = value.label else { return false }
            return preferredLabels.contains(label)
        }
        return (preferred ?? phoneNumbers.first)?.value.stringValue
    }
}

@MainActor
final class SystemContactProvider: ContactProviding {
    private let store: CNContactStore

    init(store: CNContactStore = CNContactStore()) {
        self.store = store
    }

    var accessState: ContactAccessState {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestAccess() async -> ContactAccessState {
        do {
            _ = try await store.requestAccess(for: .contacts)
            return accessState
        } catch {
            return .denied
        }
    }

    func callableContacts() throws -> [CallableContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactTypeKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var contacts: [CallableContact] = []

        try store.enumerateContacts(with: request) { contact, _ in
            if let callable = ContactMapper.callableContact(from: contact) {
                contacts.append(callable)
            }
        }
        return contacts
    }

    private static func map(_ status: CNAuthorizationStatus) -> ContactAccessState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .limited:
            return .limited
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
}
