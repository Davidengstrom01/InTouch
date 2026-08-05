import SwiftUI

struct OnboardingView: View {
    let continueAction: () async -> Void
    @State private var isRequestingAccess = false

    var body: some View {
        ZStack {
            InTouchPalette.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(InTouchPalette.accent.opacity(0.14))
                        .frame(width: 132, height: 132)
                    Image(systemName: "phone.connection.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(InTouchPalette.accent)
                }
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("InTouch")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Stay close, one call at a time.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    PrivacyPoint(icon: "person.crop.circle.badge.checkmark", text: "Only personal contacts with phone numbers are considered.")
                    PrivacyPoint(icon: "iphone", text: "Contact details stay in Apple Contacts. InTouch stores only exclusions and call-screen opens.")
                    PrivacyPoint(icon: "hand.raised.fill", text: "Nothing is uploaded, shared, or sold.")
                }
                .padding(24)
                .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                Spacer()

                Button {
                    isRequestingAccess = true
                    Task {
                        await continueAction()
                        isRequestingAccess = false
                    }
                } label: {
                    HStack {
                        if isRequestingAccess { ProgressView().tint(.white) }
                        Text(isRequestingAccess ? "Opening Contacts…" : "Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(InTouchPalette.accent)
                .disabled(isRequestingAccess)
                .accessibilityIdentifier("onboardingContinue")
            }
            .padding(24)
        }
    }
}

private struct PrivacyPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(InTouchPalette.accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
