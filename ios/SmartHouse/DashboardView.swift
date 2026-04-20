import SwiftUI

struct DashboardView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let home = appState.home {
                        headerCard(home: home)

                        Text("Rooms")
                            .font(.title2.weight(.bold))

                        ForEach(home.rooms) { room in
                            NavigationLink {
                                RoomDetailView(appState: appState, room: room)
                            } label: {
                                RoomCard(room: room, devices: appState.devices(in: room))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }

    @ViewBuilder
    private func headerCard(home: Home) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(home.name)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("Timezone: \(home.timezoneIdentifier)")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                dashboardMetric(title: "Lights On", value: "\(home.devices.filter { $0.category == .light && $0.state.actualLightState == .on }.count)")
                dashboardMetric(title: "Active Automations", value: "\(home.automations.filter(\.enabled).count)")
                dashboardMetric(title: "Alerts Today", value: "\(home.events.filter { Calendar.current.isDateInToday($0.occurredAt) }.count)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.9), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func dashboardMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoomCard: View {
    let room: Room
    let devices: [Device]

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: room.iconName)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(room.name)
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summary: String {
        let lightsOn = devices.filter { $0.category == .light && $0.state.actualLightState == .on }.count
        return "\(devices.count) devices • \(lightsOn) lights on"
    }
}

#Preview {
    DashboardView(appState: AppState(environment: .livePreview))
}
