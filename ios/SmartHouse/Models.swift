import Foundation

enum DeviceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case light
    case motionSensor = "motion_sensor"
    case camera

    var id: String { rawValue }
}

enum AutomationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case schedule
    case presenceTrigger = "presence_trigger"
    case cameraAlert = "camera_alert"

    var id: String { rawValue }
}

enum EventCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case motionDetected = "motion_detected"
    case presenceDetected = "presence_detected"
    case lightChanged = "light_changed"
    case cameraAlert = "camera_alert"
    case notificationSent = "notification_sent"

    var id: String { rawValue }
}

enum LightState: String, Codable, Sendable {
    case on
    case off
}

enum ChangeSource: String, Codable, Sendable {
    case manual
    case schedule
    case camera
    case presence
}

struct UserProfile: Identifiable, Equatable, Sendable {
    let id: String
    var displayName: String
    var email: String
    var homeID: String
}

struct Home: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var timezoneIdentifier: String
    var rooms: [Room]
    var devices: [Device]
    var automations: [Automation]
    var events: [HomeEvent]
}

struct Room: Identifiable, Hashable, Equatable, Sendable {
    let id: String
    var name: String
    var iconName: String
}

struct Device: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var category: DeviceCategory
    var roomID: String
    var vendor: String
    var state: DeviceState
    var connectivity: DeviceConnectivity
}

struct DeviceState: Equatable, Sendable {
    var desiredLightState: LightState?
    var actualLightState: LightState?
    var lastChangedBy: ChangeSource?
    var updatedAt: Date
}

enum DeviceConnectivity: String, Equatable, Sendable {
    case online
    case offline
    case pending
}

struct Automation: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var category: AutomationCategory
    var enabled: Bool
    var targetDeviceIDs: [String]
    var schedule: ScheduleRule?
    var presenceTrigger: PresenceTriggerRule?
    var cameraAlert: CameraAlertRule?
}

struct ScheduleRule: Equatable, Sendable {
    var weekdays: [Int]
    var startMinute: Int
    var endMinute: Int
    var desiredState: LightState
    var pauseUntil: Date?
}

struct PresenceTriggerRule: Equatable, Sendable {
    var sourceDeviceID: String
    var desiredState: LightState
    var cooldownSeconds: Int
    var activeWindow: ClosedRange<Int>?
}

struct CameraAlertRule: Equatable, Sendable {
    var sourceDeviceID: String
    var notificationsEnabled: Bool
    var severity: String
}

struct HomeEvent: Identifiable, Equatable, Sendable {
    let id: String
    var category: EventCategory
    var title: String
    var subtitle: String
    var roomID: String?
    var sourceDeviceID: String?
    var occurredAt: Date
    var severity: EventSeverity
}

enum EventSeverity: String, Equatable, Sendable {
    case info
    case warning
    case critical
}

extension Automation {
    var summary: String {
        switch category {
        case .schedule:
            guard let schedule else { return "Schedule is not configured." }
            return schedule.humanSummary
        case .presenceTrigger:
            guard let trigger = presenceTrigger else { return "Presence trigger is not configured." }
            return "Turns lights \(trigger.desiredState.rawValue) after presence, cooldown \(trigger.cooldownSeconds / 60)m."
        case .cameraAlert:
            guard let alert = cameraAlert else { return "Camera alert is not configured." }
            return alert.notificationsEnabled ? "Push notification on \(alert.severity) alert." : "Camera alert muted."
        }
    }
}

extension ScheduleRule {
    var humanSummary: String {
        let daySymbols = Calendar.current.shortWeekdaySymbols
        let labels = weekdays.compactMap { index -> String? in
            guard index >= 1 && index <= 7 else { return nil }
            return daySymbols[index - 1]
        }
        return "\(labels.joined(separator: ", ")) • \(startMinute.formattedClock) to \(endMinute.formattedClock) • \(desiredState.rawValue.capitalized)"
    }
}

extension Int {
    var formattedClock: String {
        let hours = self / 60
        let minutes = self % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}
