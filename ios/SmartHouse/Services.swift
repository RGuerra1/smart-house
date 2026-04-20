import Foundation

protocol AuthServicing: Sendable {
    func currentUser() async throws -> UserProfile?
    func signInWithApple() async throws -> UserProfile
    func signOut() async throws
}

protocol HomeRepository: Sendable {
    func fetchHome(for userID: String) async throws -> Home
    func toggleLight(homeID: String, deviceID: String) async throws -> Device
    func setAutomationEnabled(homeID: String, automationID: String, isEnabled: Bool) async throws
}

protocol NotificationServicing: Sendable {
    func registerForRemoteNotifications() async throws -> Bool
}
