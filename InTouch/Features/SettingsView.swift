import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("hasCompletedPrivacyIntro") private var hasCompletedPrivacyIntro = false
    @State private var isConfirmingDeletion = false

    let model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Privacy") {
                    Label("Contact details are read directly from Apple Contacts.", systemImage: "person.crop.circle")
                    Label("Nothing is uploaded, shared, or sold.", systemImage: "hand.raised.fill")
                    Label("InTouch cannot read your call history.", systemImage: "phone.badge.checkmark")
                }

                Section("Contact access") {
                    LabeledContent("Status", value: accessDescription)
                    if model.accessState == .denied {
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }

                Section {
                    if model.excludedPeople.isEmpty {
                        Text("No one has been excluded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.excludedPeople) { person in
                            HStack {
                                Text(person.displayName)
                                Spacer()
                                Button("Undo") {
                                    model.restore(contactID: person.id)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Restore \(person.displayName)")
                            }
                        }
                    }
                } header: {
                    Text("Excluded people")
                } footer: {
                    Text("Restored people can appear in suggestions again.")
                }

                Section("Your data") {
                    Button("Delete All InTouch Data", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                    .accessibilityIdentifier("deleteAllDataButton")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete all InTouch data?",
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete All Data", role: .destructive) {
                    model.deleteAllData()
                    hasCompletedPrivacyIntro = false
                    dismiss()
                }
            } message: {
                Text("This removes exclusions and call-screen activity from this device. Your Apple Contacts are not changed.")
            }
        }
    }

    private var accessDescription: String {
        switch model.accessState {
        case .notDetermined: "Not requested"
        case .limited: "Limited"
        case .authorized: "Allowed"
        case .denied: "Not allowed"
        }
    }
}
