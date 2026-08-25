import XCTest
@testable import Tickytacky

final class FocusTests: XCTestCase {
    func testDurationSecondsMatchMinutes() {
        let work = FocusSettings.workMinutes
        let short = FocusSettings.shortBreakMinutes
        let long = FocusSettings.longBreakMinutes
        XCTAssertEqual(FocusSettings.durationSeconds(for: .work), work * 60)
        XCTAssertEqual(FocusSettings.durationSeconds(for: .shortBreak), short * 60)
        XCTAssertEqual(FocusSettings.durationSeconds(for: .longBreak), long * 60)
    }

    func testParsesFocusUserInfo() {
        let link = ReminderDeepLink.parse(userInfo: [
            ReminderUserInfoKey.kind: ReminderDeepLinkKind.focus.rawValue,
            ReminderUserInfoKey.sessionId: "abc",
        ])
        XCTAssertEqual(link, .focus(sessionId: "abc"))
    }

    func testParsesFocusURL() {
        let url = URL(string: "tickytacky://focus/sess1")!
        XCTAssertEqual(ReminderDeepLink.parse(url: url), .focus(sessionId: "sess1"))
    }
}
