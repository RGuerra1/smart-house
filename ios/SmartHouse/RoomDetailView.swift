import SwiftUI

struct RoomDetailView: View {
    @Bindable var appState: AppState
    let room: Room

    var body: some View {
        List {
            Section("Devices") {
                ForEach(appState.devices(in: room)) { device in
                    if device.category == .light {
                        Button {
                            Task {
                                await appState.toggleLight(device)
                            }
                        } label: {
                            DeviceRow(device: device)
                        }
                        .buttonStyle(.plain)
                    } else {
                        DeviceRow(device: device)
                    }
                }
            }

            Section("Active Automations") {
                ForEach(filteredAutomations) { automation in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(automation.name)
                                .font(.headline)
                            Spacer()
                            Text(automation.enabled ? "Enabled" : "Paused")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(automation.enabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15), in: Capsule())
                        }
                        Text(automation.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(room.name)
    }

    private var filteredAutomations: [Automation] {
        guard let home = appState.home else { return [] }
        let roomDeviceIDs = Set(appState.devices(in: room).map(\.id))
        return home.automations.filter { automation in
            !roomDeviceIDs.isDisjoint(with: automation.targetDeviceIDs) ||
            automation.presenceTrigger?.sourceDeviceID == appState.devices(in: room).first(where: { $0.category == .motionSensor })?.id ||
            automation.cameraAlert?.sourceDeviceID == appState.devices(in: room).first(where: { $0.category == .camera })?.id
        }
    }
}

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.headline)
                Text("\(device.vendor) • \(device.connectivity.rawValue.capitalized)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if device.category == .light {
                Text(device.state.actualLightState == .on ? "On" : "Off")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(device.state.actualLightState == .on ? .yellow : .secondary)
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(.blue)
            }
        }
    }

    private var iconName: String {
        switch device.category {
        case .light:
            return "lightbulb.fill"
        case .motionSensor:
            return "figure.walk.motion"
        case .camera:
            return "video.fill"
        }
    }
}
