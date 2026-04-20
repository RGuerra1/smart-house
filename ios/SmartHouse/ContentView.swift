import SwiftUI

struct ContentView: View {
    @State private var appState = AppState(environment: .livePreview)

    var body: some View {
        Group {
            if appState.isLoading && appState.currentUser == nil {
                ProgressView("Loading Smart House…")
                    .task {
                        await appState.bootstrap()
                    }
            } else if appState.currentUser == nil {
                SignInView(appState: appState)
                    .task {
                        if appState.home == nil {
                            await appState.bootstrap()
                        }
                    }
            } else {
                TabView {
                    DashboardView(appState: appState)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                    AutomationsView(appState: appState)
                        .tabItem {
                            Label("Automations", systemImage: "clock.arrow.circlepath")
                        }

                    EventHistoryView(appState: appState)
                        .tabItem {
                            Label("Events", systemImage: "bell.badge.fill")
                        }

                    SettingsView(appState: appState)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.currentUser != nil)
    }
}

#Preview {
    ContentView()
}
