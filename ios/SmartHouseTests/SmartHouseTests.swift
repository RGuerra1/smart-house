import XCTest
@testable import SmartHouse

final class SmartHouseTests: XCTestCase {
    func testScheduleRuleSummaryUsesReadableClock() {
        let rule = ScheduleRule(weekdays: [2, 4, 6], startMinute: 18 * 60, endMinute: 22 * 60 + 30, desiredState: .on, pauseUntil: nil)

        XCTAssertTrue(rule.humanSummary.contains("18:00"))
        XCTAssertTrue(rule.humanSummary.contains("22:30"))
    }

    @MainActor
    func testAppStateSignInLoadsHome() async {
        let appState = AppState(environment: .livePreview)

        await appState.signIn()

        XCTAssertEqual(appState.currentUser?.displayName, "RG House Admin")
        XCTAssertEqual(appState.home?.name, "Santiago Home")
        XCTAssertTrue(appState.notificationsEnabled)
    }
}
