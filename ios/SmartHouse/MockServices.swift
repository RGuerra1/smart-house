import Foundation

actor MockSessionStorage {
    private var signedInUser: UserProfile?
    private var home: Home = SampleData.home

    func currentUser() -> UserProfile? {
        signedInUser
    }

    func signIn() -> UserProfile {
        let profile = SampleData.user
        signedInUser = profile
        return profile
    }

    func signOut() {
        signedInUser = nil
    }

    func fetchHome() -> Home {
        home
    }

    func toggleLight(deviceID: String) -> Device {
        guard let index = home.devices.firstIndex(where: {$0.id == deviceID}) else {
            return home.devices[0]
        }

        var device = home.devices[index]
        let nextState: LightState = device.state.actualLightState == .on ? .off : .on
        device.state.actualLightState = nextState
        device.state.desiredLightState = nextState
        device.state.lastChangedBy = .manual
        device.state.updatedAt = .now
        home.devices[index] = device

        let event = HomeEvent(
            id: UUID().uuidString,
            category: .lightChanged,
            title: "\(device.name) turned \(nextState.rawValue)",
            subtitle: "Manual control from iPhone",
            roomID: device.roomID,
            sourceDeviceID: device.id,
            occurredAt: .now,
            severity: .info
        )
        home.events.insert(event, at: 0)
        return device
    }

    func setAutomationEnabled(automationID: String, isEnabled: Bool) {
        guard let index = home.automations.firstIndex(where: {$0.id == automationID}) else {
            return
        }
        home.automations[index].enabled = isEnabled
    }
}

struct MockAuthService: AuthServicing {
    private let storage: MockSessionStorage

    init(storage: MockSessionStorage) {
        self.storage = storage
    }

    func currentUser() async throws -> UserProfile? {
        await storage.currentUser()
    }

    func signInWithApple() async throws -> UserProfile {
        try await Task.sleep(for: .milliseconds(300))
        return await storage.signIn()
    }

    func signOut() async throws {
        await storage.signOut()
    }
}

struct MockHomeRepository: HomeRepository {
    private let storage: MockSessionStorage

    init(storage: MockSessionStorage) {
        self.storage = storage
    }

    func fetchHome(for userID: String) async throws -> Home {
        _ = userID
        try await Task.sleep(for: .milliseconds(150))
        return await storage.fetchHome()
    }

    func toggleLight(homeID: String, deviceID: String) async throws -> Device {
        _ = homeID
        return await storage.toggleLight(deviceID: deviceID)
    }

    func setAutomationEnabled(homeID: String, automationID: String, isEnabled: Bool) async throws {
        _ = homeID
        await storage.setAutomationEnabled(automationID: automationID, isEnabled: isEnabled)
    }
}

struct MockNotificationService: NotificationServicing {
    func registerForRemoteNotifications() async throws -> Bool {
        true
    }
}

enum SampleData {
    static let rooms: [Room] = [
        Room(id: "living-room", name: "Living Room", iconName: "sofa.fill"),
        Room(id: "entry", name: "Entry", iconName: "door.left.hand.open"),
        Room(id: "bedroom", name: "Bedroom", iconName: "bed.double.fill")
    ]

    static let devices: [Device] = [
        Device(
            id: "light-living-main",
            name: "Living Room Lamp",
            category: .light,
            roomID: "living-room",
            vendor: "Matter / Tapo L535E",
            state: DeviceState(desiredLightState: .on, actualLightState: .on, lastChangedBy: .schedule, updatedAt: .now.addingTimeInterval(-900)),
            connectivity: .online
        ),
        Device(
            id: "light-entry-main",
            name: "Entry Light",
            category: .light,
            roomID: "entry",
            vendor: "Matter / Hue fallback",
            state: DeviceState(desiredLightState: .off, actualLightState: .off, lastChangedBy: .presence, updatedAt: .now.addingTimeInterval(-1800)),
            connectivity: .online
        ),
        Device(
            id: "sensor-entry-presence",
            name: "Entry Presence Sensor",
            category: .motionSensor,
            roomID: "entry",
            vendor: "Aqara P2",
            state: DeviceState(desiredLightState: nil, actualLightState: nil, lastChangedBy: nil, updatedAt: .now.addingTimeInterval(-240)),
            connectivity: .online
        ),
        Device(
            id: "camera-living",
            name: "Living Room Camera",
            category: .camera,
            roomID: "living-room",
            vendor: "Aqara G2H Pro",
            state: DeviceState(desiredLightState: nil, actualLightState: nil, lastChangedBy: nil, updatedAt: .now.addingTimeInterval(-420)),
            connectivity: .online
        )
    ]

    static let automations: [Automation] = [
        Automation(
            id: "schedule-evening",
            name: "Evening Comfort",
            category: .schedule,
            enabled: true,
            targetDeviceIDs: ["light-living-main"],
            schedule: ScheduleRule(weekdays: [2, 3, 4, 5, 6], startMinute: 18 * 60, endMinute: 23 * 60, desiredState: .on, pauseUntil: nil),
            presenceTrigger: nil,
            cameraAlert: nil
        ),
        Automation(
            id: "presence-entry-night",
            name: "Entryway Presence",
            category: .presenceTrigger,
            enabled: true,
            targetDeviceIDs: ["light-entry-main"],
            schedule: nil,
            presenceTrigger: PresenceTriggerRule(sourceDeviceID: "sensor-entry-presence", desiredState: .on, cooldownSeconds: 600, activeWindow: nil),
            cameraAlert: nil
        ),
        Automation(
            id: "camera-security",
            name: "Security Camera Alerts",
            category: .cameraAlert,
            enabled: true,
            targetDeviceIDs: [],
            schedule: nil,
            presenceTrigger: nil,
            cameraAlert: CameraAlertRule(sourceDeviceID: "camera-living", notificationsEnabled: true, severity: "warning")
        )
    ]

    static let events: [HomeEvent] = [
        HomeEvent(id: "event-1", category: .cameraAlert, title: "Living Room Camera detected motion", subtitle: "Security alert sent to iPhone", roomID: "living-room", sourceDeviceID: "camera-living", occurredAt: .now.addingTimeInterval(-600), severity: .warning),
        HomeEvent(id: "event-2", category: .presenceDetected, title: "Entry presence detected", subtitle: "Aqara sensor triggered night lighting", roomID: "entry", sourceDeviceID: "sensor-entry-presence", occurredAt: .now.addingTimeInterval(-1200), severity: .info),
        HomeEvent(id: "event-3", category: .lightChanged, title: "Living Room Lamp turned on", subtitle: "Scheduled automation executed", roomID: "living-room", sourceDeviceID: "light-living-main", occurredAt: .now.addingTimeInterval(-1800), severity: .info)
    ]

    static let home = Home(
        id: "home-santiago",
        name: "Santiago Home",
        timezoneIdentifier: "America/Santiago",
        rooms: rooms,
        devices: devices,
        automations: automations,
        events: events
    )

    static let user = UserProfile(
        id: "user-admin",
        displayName: "RG House Admin",
        email: "admin@example.com",
        homeID: home.id
    )
}
