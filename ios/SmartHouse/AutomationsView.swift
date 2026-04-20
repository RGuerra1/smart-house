import SwiftUI

struct AutomationsView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                if let home = appState.home {
                    ForEach(home.automations) { automation in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(automation.name)
                                        .font(.headline)
                                    Text(automation.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { automation.enabled },
                                    set: { enabled in
                                        Task {
                                            await appState.setAutomation(automation, enabled: enabled)
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }

                            Text(automation.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Automations")
        }
    }
}

#Preview {
    AutomationsView(appState: AppState(environment: .livePreview))
}
