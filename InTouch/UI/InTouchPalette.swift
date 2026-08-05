import SwiftUI

enum InTouchPalette {
    static let accent = Color(red: 0.72, green: 0.29, blue: 0.22)
    static let background = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1)
                : UIColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1)
        }
    )
}
