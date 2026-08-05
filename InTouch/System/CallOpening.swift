import Foundation
import UIKit

enum CallURL {
    static func make(from phoneNumber: String) -> URL? {
        let digits = phoneNumber.compactMap(\.wholeNumberValue).map(String.init).joined()
        guard !digits.isEmpty else { return nil }

        let hasInternationalPrefix = phoneNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix("+")
        return URL(string: "tel:\(hasInternationalPrefix ? "+" : "")\(digits)")
    }
}

@MainActor
protocol CallOpening {
    func openCall(to phoneNumber: String) async -> Bool
}

@MainActor
struct SystemCallOpener: CallOpening {
    func openCall(to phoneNumber: String) async -> Bool {
        guard let url = CallURL.make(from: phoneNumber) else { return false }
        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { accepted in
                continuation.resume(returning: accepted)
            }
        }
    }
}
