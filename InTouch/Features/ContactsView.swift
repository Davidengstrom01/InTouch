import SwiftUI

struct MainTabView: View {
    let model: AppModel

    var body: some View {
        TabView {
            HomeView(model: model)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ContactsView(model: model)
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }
        }
        .tint(InTouchPalette.accent)
    }
}

struct ContactsView: View {
    let model: AppModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.contactInsights.isEmpty {
                    ContentUnavailableView(
                        "No contacts available",
                        systemImage: "person.2.slash",
                        description: Text("Allow Contacts access or add someone with a phone number.")
                    )
                } else {
                    contactList
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
        }
    }

    private var contactList: some View {
        List {
            Section("People") {
                if activeContacts.isEmpty {
                    Text("No matching people.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeContacts) { insight in
                        ContactInsightRow(insight: insight) {
                            model.markNotInterested(contactID: insight.id)
                        }
                    }
                }
            }

            if !excludedContacts.isEmpty {
                Section {
                    ForEach(excludedContacts) { insight in
                        HStack(spacing: 12) {
                            ContactAvatar(contact: insight.contact, size: 42)
                            Text(insight.contact.displayName)
                            Spacer()
                            Button("Undo") {
                                model.restore(contactID: insight.id)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Restore \(insight.contact.displayName)")
                        }
                    }
                } header: {
                    Text("Not interested")
                } footer: {
                    Text("Restored people can appear in suggestions again.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var activeContacts: [ContactInsight] {
        filteredContacts.filter { !$0.isExcluded }
    }

    private var excludedContacts: [ContactInsight] {
        filteredContacts.filter(\.isExcluded)
    }

    private var filteredContacts: [ContactInsight] {
        guard !searchText.isEmpty else { return model.contactInsights }
        return model.contactInsights.filter {
            $0.contact.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct ContactInsightRow: View {
    let insight: ContactInsight
    let notInterestedAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                ContactInsightDetailView(insight: insight, notInterestedAction: notInterestedAction)
            } label: {
                HStack(spacing: 12) {
                    ContactAvatar(contact: insight.contact, size: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.contact.displayName)
                            .font(.headline)
                        Text(activitySummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button(action: notInterestedAction) {
                Label("Not interested", systemImage: "hand.thumbsdown")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(InTouchPalette.accent)
            .accessibilityLabel("Not interested in \(insight.contact.displayName)")
            .accessibilityHint("Removes this person from future suggestions")
        }
        .padding(.vertical, 5)
    }

    private var activitySummary: String {
        guard let lastOpenedAt = insight.lastOpenedAt else { return "Never selected in InTouch" }
        let count = insight.callOpenCount == 1 ? "1 call screen" : "\(insight.callOpenCount) call screens"
        return "\(count) · Last \(lastOpenedAt.formatted(.relative(presentation: .named)))"
    }
}

private struct ContactInsightDetailView: View {
    let insight: ContactInsight
    let notInterestedAction: () -> Void

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ContactAvatar(contact: insight.contact, size: 90)
                    Text(insight.contact.displayName)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("InTouch activity") {
                LabeledContent("Call screens opened", value: insight.callOpenCount.formatted())
                LabeledContent("Last opened", value: lastOpenedDescription)
            }

            if !insight.openedAt.isEmpty {
                Section("History") {
                    ForEach(insight.openedAt, id: \.self) { date in
                        Label {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                        } icon: {
                            Image(systemName: "phone.arrow.up.right")
                                .foregroundStyle(InTouchPalette.accent)
                        }
                    }
                }
            }

            Section {
                Button("Not interested", role: .destructive, action: notInterestedAction)
                    .accessibilityLabel("Not interested in \(insight.contact.displayName)")
            } footer: {
                Text("This removes the person from suggestions. You can undo it from the Contacts tab or Settings.")
            }
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lastOpenedDescription: String {
        insight.lastOpenedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
    }
}
