import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = appState.currentUser {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        Task {
                            await appState.signOut()
                        }
                    }
                }

                Section("System") {
                    LabeledContent("Notifications") {
                        Text(appState.notificationsEnabled ? "Enabled" : "Disabled")
                    }
                    LabeledContent("Target Market") {
                        Text("Chile / iPhone household")
                    }
                    LabeledContent("Default Devices") {
                        Text("Matter lights + Aqara presence")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(appState: AppState(environment: .livePreview))
}
