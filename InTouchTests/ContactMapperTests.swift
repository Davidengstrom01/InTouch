import Contacts
import Testing
@testable import InTouch

@MainActor
struct ContactMapperTests {
    @Test("A mobile number is preferred over other numbers")
    func mobileNumberIsPreferred() {
        let contact = CNMutableContact()
        contact.givenName = "Alex"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: "08 123 45")),
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+46 70 123 45 67"))
        ]

        let mapped = ContactMapper.callableContact(from: contact)

        #expect(mapped?.displayName == "Alex")
        #expect(mapped?.phoneNumber == "+46 70 123 45 67")
    }

    @Test("Organizations are not included in the personal suggestion pool")
    func organizationIsExcluded() {
        let contact = CNMutableContact()
        contact.contactType = .organization
        contact.organizationName = "Example Company"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: "08 123 45"))
        ]

        #expect(ContactMapper.callableContact(from: contact) == nil)
    }
}
