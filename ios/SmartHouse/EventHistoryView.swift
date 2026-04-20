import SwiftUI

struct EventHistoryView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                if let home = appState.home {
                    ForEach(home.events.sorted(by: { $0.occurredAt > $1.occurredAt })) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(event.title, systemImage: symbol(for: event.category))
                                    .font(.headline)
                                Spacer()
                                Text(event.occurredAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(event.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(appState.roomName(for: event.roomID))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(color(for: event.severity).opacity(0.12), in: Capsule())
                                .foregroundStyle(color(for: event.severity))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Events")
        }
    }

    private func symbol(for category: EventCategory) -> String {
        switch category {
        case .motionDetected, .presenceDetected:
            return "figure.walk.motion"
        case .lightChanged:
            return "lightbulb.max.fill"
        case .cameraAlert:
            return "video.badge.ellipsis"
        case .notificationSent:
            return "bell.badge.fill"
        }
    }

    private func color(for severity: EventSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

#Preview {
    EventHistoryView(appState: AppState(environment: .livePreview))
}
