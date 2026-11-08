import XCTest

/// Runs only with a simulator external display attached:
/// TEST_RUNNER_ADULT_EXTERNAL_DISPLAY=1 xcodebuild test ... (Simulator ▸ I/O ▸ External Displays).
@MainActor final class AdultExternalDisplayUITests: XCTestCase {
    func testSecondScreenFollowsCarouselAndModes() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ADULT_EXTERNAL_DISPLAY"] == "1", "Attach a simulator external display to run")
        let app = XCUIApplication()
        app.launchArguments = ["--qa-tab=Explore", "--qa-guide=wash-your-first-load"]
        app.launch()
        func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func choose(_ mode: String) {
            app.buttons["guide-more"].firstMatch.tap()
            let item = app.buttons[mode].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5), "Second-screen modes appear only while a display is connected")
            item.tap()
            sleep(3) // the shell captures the external display here
        }
        XCTAssertTrue(element("guide-reader").waitForExistence(timeout: 10))
        sleep(8) // the shell (re)attaches the display after launch
        let overview = app.buttons["Overview"].firstMatch
        if overview.exists { overview.tap() }
        choose("Step and context")             // capture 1: overview, expanded
        element("start-guide").tap(); sleep(1)
        choose("Current step")                 // capture 2: step 1, current
        element("done-step").tap(); sleep(2)
        choose("Step and context")             // capture 3: step 2, expanded
        choose("Whole guide")                  // capture 4: whole guide, step 2 highlighted
        XCTAssertTrue(element("done-step").isHittable, "Phone stays fully usable")
        sleep(12)                              // the shell disconnects and reconnects the display here
        XCTAssertTrue(element("guide-reader").exists, "Reader survives disconnect and reconnect")
        element("skip-step").tap(); sleep(3)   // capture 5: after reconnect, follows to step 3
        XCTAssertEqual(app.state, .runningForeground)
    }
}
