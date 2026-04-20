import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private let environment: AppEnvironment

    var currentUser: UserProfile?
    var home: Home?
    var isLoading = false
    var errorMessage: String?
    var notificationsEnabled = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await environment.authService.currentUser()
            if let currentUser {
                home = try await environment.homeRepository.fetchHome(for: currentUser.id)
                notificationsEnabled = try await environment.notificationService.registerForRemoteNotifications()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await environment.authService.signInWithApple()
            if let currentUser {
                home = try await environment.homeRepository.fetchHome(for: currentUser.id)
                notificationsEnabled = try await environment.notificationService.registerForRemoteNotifications()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await environment.authService.signOut()
            currentUser = nil
            home = nil
            notificationsEnabled = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLight(_ device: Device) async {
        guard let home else { return }

        do {
            let updated = try await environment.homeRepository.toggleLight(homeID: home.id, deviceID: device.id)
            replace(device: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setAutomation(_ automation: Automation, enabled: Bool) async {
        guard var home else { return }

        do {
            try await environment.homeRepository.setAutomationEnabled(homeID: home.id, automationID: automation.id, isEnabled: enabled)
            if let index = home.automations.firstIndex(where: {$0.id == automation.id}) {
                home.automations[index].enabled = enabled
                self.home = home
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func room(for id: String) -> Room? {
        home?.rooms.first(where: {$0.id == id})
    }

    func devices(in room: Room) -> [Device] {
        home?.devices.filter {$0.roomID == room.id} ?? []
    }

    func roomName(for id: String?) -> String {
        guard let id, let room = room(for: id) else {
            return "Whole Home"
        }
        return room.name
    }

    private func replace(device: Device) {
        guard var home else { return }
        if let index = home.devices.firstIndex(where: {$0.id == device.id}) {
            home.devices[index] = device
            self.home = home
        }
    }
}
