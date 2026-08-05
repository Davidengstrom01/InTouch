import SwiftUI
import UIKit

struct HomeView: View {
    let model: AppModel
    @State private var isShowingSettings = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [InTouchPalette.background, InTouchPalette.accent.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                content
                    .padding(.horizontal, 24)
            }
            .navigationTitle("InTouch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(model: model)
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button("OK") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "Please try again.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Finding your people…")
        case .needsPermission:
            AccessStateView(
                icon: "person.crop.circle.badge.plus",
                title: "Your contacts, your choice",
                message: "Allow Contacts access so InTouch can find people with phone numbers.",
                buttonTitle: "Continue"
            ) {
                Task { await model.requestContactsAccess() }
            }
        case .permissionDenied:
            AccessStateView(
                icon: "lock.fill",
                title: "Contacts access is off",
                message: "InTouch can’t suggest anyone until Contacts access is enabled in Settings.",
                buttonTitle: "Open Settings"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
        case .noContacts:
            AccessStateView(
                icon: "person.crop.circle.badge.exclamationmark",
                title: "No callable contacts found",
                message: "Add a personal contact with a phone number, or make more contacts available to InTouch.",
                buttonTitle: "Refresh"
            ) {
                Task { await model.refresh() }
            }
        case .allExcluded:
            AccessStateView(
                icon: "heart.slash",
                title: "No one left in the hat",
                message: "Everyone available has been excluded. You can bring someone back in Settings.",
                buttonTitle: "Review excluded people"
            ) {
                isShowingSettings = true
            }
        case .failed:
            AccessStateView(
                icon: "arrow.clockwise.circle",
                title: "Let’s try that again",
                message: "InTouch couldn’t refresh your contacts right now.",
                buttonTitle: "Retry"
            ) {
                Task { await model.refresh() }
            }
        case .ready:
            readyContent
        }
    }

    private var readyContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Who should you call?")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("A little nudge toward someone you know.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                HStack(spacing: 12) {
                    ActivityTile(value: model.summary.callsOpened, label: "Calls opened", identifier: "callsOpenedValue")
                    ActivityTile(value: model.summary.uniquePeople, label: "People this month", identifier: "uniquePeopleValue")
                }

                if let suggestion = model.currentSuggestion {
                    SuggestionCard(
                        contact: suggestion,
                        callAction: { Task { await model.callCurrentSuggestion() } },
                        rejectAction: model.rejectCurrentSuggestion
                    )
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 18) {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                model.requestSuggestion()
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                Text("Who should I call?")
                                    .font(.title3.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 176)
                            .background(InTouchPalette.accent, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                            .shadow(color: InTouchPalette.accent.opacity(0.25), radius: 18, y: 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Suggests one person from your contacts")
                        .accessibilityIdentifier("suggestButton")

                        Text("Stay close, one call at a time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("InTouch only counts calling screens opened from this app. It never reads your call history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
        }
    }
}

private struct ActivityTile: View {
    let value: Int
    let label: String
    let identifier: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value, format: .number)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .accessibilityIdentifier(identifier)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SuggestionCard: View {
    let contact: CallableContact
    let callAction: () -> Void
    let rejectAction: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Text("How about")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            ContactAvatar(contact: contact, size: 112)

            Text(contact.displayName)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("suggestedContactName")

            Button(action: callAction) {
                Label("Call", systemImage: "phone.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(InTouchPalette.accent)
            .accessibilityLabel("Call \(contact.displayName)")
            .accessibilityHint("Opens the iPhone calling screen with the phone number ready")
            .accessibilityIdentifier("callButton")

            Button("I don’t want to call this person", action: rejectAction)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHint("Permanently removes this person from suggestions. This can be undone in Settings.")
                .accessibilityIdentifier("rejectButton")
        }
        .padding(26)
        .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
    }
}

private struct AccessStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(InTouchPalette.accent)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(InTouchPalette.accent)
        }
        .padding(28)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct ContactAvatar: View {
    let contact: CallableContact
    let size: CGFloat

    var body: some View {
        Group {
            if let data = contact.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(InTouchPalette.accent.opacity(0.16))
                    Text(initials)
                        .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                        .foregroundStyle(InTouchPalette.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        contact.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
