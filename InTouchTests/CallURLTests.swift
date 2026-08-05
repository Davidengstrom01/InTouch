import Foundation
import Testing
@testable import InTouch

@MainActor
struct CallURLTests {
    @Test("The calling URL contains only the dialable phone number")
    func callURLIsReadyForConfirmation() {
        let url = CallURL.make(from: "+46 (70) 123-45 67")

        #expect(url?.absoluteString == "tel:+46701234567")
    }

    @Test("A phone number without digits cannot open the calling screen")
    func invalidNumberHasNoCallURL() {
        #expect(CallURL.make(from: "not a number") == nil)
    }
}
