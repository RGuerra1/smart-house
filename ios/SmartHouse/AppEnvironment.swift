import Foundation

struct AppEnvironment: Sendable {
    let authService: AuthServicing
    let homeRepository: HomeRepository
    let notificationService: NotificationServicing

    static let livePreview: AppEnvironment = {
        let storage = MockSessionStorage()
        return AppEnvironment(
            authService: MockAuthService(storage: storage),
            homeRepository: MockHomeRepository(storage: storage),
            notificationService: MockNotificationService()
        )
    }()
}
