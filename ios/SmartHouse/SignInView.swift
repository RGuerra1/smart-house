import SwiftUI

struct SignInView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Smart House")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Apple-native smart home control for Chile, built around Matter lights, Aqara presence, and Firebase-backed event history.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "lightbulb.max.fill", title: "Scheduled lighting", subtitle: "Weekday automations with pause exceptions.")
                featureRow(icon: "figure.walk.motion", title: "Presence-triggered lights", subtitle: "Aqara-ready motion and presence flows.")
                featureRow(icon: "bell.badge.fill", title: "Security notifications", subtitle: "Camera alerts and event history in one place.")
            }

            Button {
                Task {
                    await appState.signIn()
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.cyan.opacity(0.08), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SignInView(appState: AppState(environment: .livePreview))
}
