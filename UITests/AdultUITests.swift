import XCTest
#if os(iOS)
import UIKit
#endif

@MainActor final class AdultUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        await MainActor.run {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom != .pad { XCUIDevice.shared.orientation = .portrait }
        #endif
        self.app.launch()
        XCTAssertTrue(self.app.scrollViews["guide-collection"].waitForExistence(timeout: 15))
        }
    }

    private func shot(_ name: String) {
        #if os(macOS)
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        #else
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        #endif
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func search(_ query: String) {
        let search = app.searchFields.firstMatch
        if !search.exists {
            app.scrollViews["guide-collection"].swipeDown()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(query)
        #if os(iOS)
        let key = app.keyboards.buttons["Search"]
        if key.exists { key.tap() }
        #endif
    }

    private func goHome() {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists, back.label != "open-settings", back.label != "Settings" { back.tap() }
    }

    private func selectSection(_ name: String) {
        #if os(iOS)
        if app.tabBars.buttons[name].exists { app.tabBars.buttons[name].tap(); return }
        #endif
        let row = app.buttons[name].firstMatch
        if row.exists { row.tap() } else { app.staticTexts[name].firstMatch.tap() }
    }

    func testDarkAppearanceAndAccessibilityText() throws {
        app.terminate()
        app.launchArguments = ["--qa-dark", "--qa-accessibility-text"]
        app.launch()
        XCTAssertTrue(app.scrollViews["guide-collection"].waitForExistence(timeout: 10))
        shot("11-dark-large-guides")
        app.buttons["featured-guide"].tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        shot("12-dark-large-reader")
        let reader = app.scrollViews["guide-reader"]
        // SwiftUI combines nearby prose into one accessibility text element;
        // its hit-test frame can be visible before the source link itself.
        for _ in 0..<5 { reader.swipeUp() }
        shot("13-dark-large-sources")
        let source = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Whirlpool laundry basics")).firstMatch
        XCTAssertTrue(source.exists)
    }

    func testGuidesSearchSaveProgressAndGallery() throws {
        shot("01-guides")
        let featured = app.buttons["featured-guide"].firstMatch
        let featuredLink = app.otherElements["featured-guide"].firstMatch
        if featured.exists { featured.tap() }
        else if featuredLink.exists { featuredLink.tap() }
        else { app.buttons["guide-read-a-care-label"].tap() }
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        shot("02-guide")
        let save = app.buttons["save-guide"]
        if save.label == "Save guide" { save.tap() }
        XCTAssertEqual(save.label, "Unsave guide")
        let step = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'step-'")).firstMatch
        XCTAssertTrue(step.exists)
        if (step.value as? String) != "Completed" { step.tap() }
        XCTAssertEqual(step.value as? String, "Completed")
        shot("03-steps")
        let reader = app.scrollViews["guide-reader"]
        reader.swipeUp()
        reader.swipeUp()
        shot("04-sources")
        #if os(iOS)
        if app.tabBars.firstMatch.exists {
            goHome()
        }
        #endif
        selectSection("Saved")
        XCTAssertTrue(app.buttons["guide-wash-your-first-load"].waitForExistence(timeout: 5) || app.links["guide-wash-your-first-load"].exists)
        #if os(macOS)
        app.buttons["guide-wash-your-first-load"].tap()
        #else
        if !app.tabBars.firstMatch.exists { app.buttons["guide-wash-your-first-load"].tap() }
        #endif
        shot("05-saved")
        selectSection("Guides")
        search("401")
        shot("06-search")
        let retirement = app.buttons["guide-start-with-your-401k"]
        if retirement.exists { retirement.tap() } else { app.links["guide-start-with-your-401k"].tap() }
        XCTAssertTrue(app.staticTexts["United States rules"].waitForExistence(timeout: 5))
        shot("07-money")
        app.buttons["remind-guide"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForExistence(timeout: 5))
        shot("08-reminder")
        let sound = app.switches["Play a sound"]
        XCTAssertTrue(sound.exists)
        if sound.value as? String == "1" { sound.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap() }
        XCTAssertEqual(sound.value as? String, "0")
        app.buttons["save-reminder"].tap()
        #if os(iOS)
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        #endif
        XCTAssertTrue(app.buttons["save-reminder"].waitForNonExistence(timeout: 10))
        app.terminate()
        app.launch()
        selectSection("Reminders")
        let reminderRow = app.buttons["guide-start-with-your-401k"]
        XCTAssertTrue(reminderRow.waitForExistence(timeout: 5))
        reminderRow.tap()
        shot("09-reminders")
        app.buttons["remind-guide"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["Play a sound"].value as? String, "0")
        app.buttons["remove-reminder"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForNonExistence(timeout: 5))
        #if os(iOS)
        if app.tabBars.firstMatch.exists { goHome() }
        #endif
        selectSection("Reminders")
        XCTAssertTrue(app.buttons["guide-start-with-your-401k"].waitForNonExistence(timeout: 5))
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shot("10-settings")
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        selectSection("Saved")
        XCTAssertTrue(app.buttons["guide-wash-your-first-load"].waitForExistence(timeout: 5) || app.links["guide-wash-your-first-load"].exists)
    }
}
