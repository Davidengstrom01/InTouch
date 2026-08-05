import Contacts
import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedPrivacyIntro") private var hasCompletedPrivacyIntro = false
    @Environment(\.scenePhase) private var scenePhase

    let model: AppModel
    let skipOnboarding: Bool

    init(model: AppModel, skipOnboarding: Bool = false) {
        self.model = model
        self.skipOnboarding = skipOnboarding
    }

    var body: some View {
        Group {
            if hasCompletedPrivacyIntro || skipOnboarding {
                HomeView(model: model)
            } else {
                OnboardingView {
                    hasCompletedPrivacyIntro = true
                    await model.requestContactsAccess()
                }
            }
        }
        .task {
            if hasCompletedPrivacyIntro || skipOnboarding {
                await model.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, hasCompletedPrivacyIntro || skipOnboarding else { return }
            Task { await model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .CNContactStoreDidChange)) { _ in
            guard hasCompletedPrivacyIntro || skipOnboarding else { return }
            Task { await model.refresh() }
        }
    }
}
