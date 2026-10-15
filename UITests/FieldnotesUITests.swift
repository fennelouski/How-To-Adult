import XCTest
#if os(iOS)
import UIKit
#endif

/// Real navigation and persistence checks. Never grants notification or other permissions.
@MainActor final class FieldnotesUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            app = XCUIApplication()
        }
    }
    private func launch(_ arguments: [String] = []) {
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.scrollViews["guide-collection"].waitForExistence(timeout: 15))
    }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, up: Bool = true) {
        for _ in 0..<12 {
            if element.isHittable { return }
            if up { scroll.swipeUp() } else { scroll.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }
    func testSearchSavedProgressAndFullSizeArt() {
        launch()
        shot("phone-discovery")
        let featured = app.buttons["featured-guide"].firstMatch
        reveal(featured, in: app.scrollViews["guide-collection"])
        featured.tap()
        let reader = app.scrollViews["guide-reader"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Do not sew clothing while wearing it")).firstMatch.exists)
        shot("phone-reader")
        let save = app.buttons["save-guide"]
        if save.label == "Save guide" { save.tap() }
        XCTAssertEqual(save.label, "Unsave guide")
        let step = app.buttons["step-repair-a-short-loose-cotton-hem-inspect-fold"]
        reveal(step, in: reader)
        if !(step.value as? String ?? "").hasPrefix("Checked") { step.tap() }
        XCTAssertTrue((step.value as? String ?? "").hasPrefix("Checked"))
        shot("phone-steps")
        let imageAction = app.buttons["View full size"].firstMatch
        reveal(imageAction, in: reader, up: false)
        imageAction.tap()
        XCTAssertTrue(app.navigationBars["Illustration"].waitForExistence(timeout: 5))
        let zoom = app.buttons["Zoom in"]
        XCTAssertTrue(zoom.exists)
        zoom.tap()
        shot("phone-full-size-art")
        app.buttons["Done"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Saved"].tap()
        let saved = app.buttons["guide-repair-a-short-loose-cotton-hem"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        shot("phone-saved")
        app.terminate()
        launch()
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 of 5 steps checked"].exists)
        app.tabBars.buttons["Guides"].tap()
        let search = app.textFields["guide-search"]
        reveal(search, in: app.scrollViews["guide-collection"], up: false)
        search.tap(); search.typeText("laundry\n")
        XCTAssertFalse(app.buttons["featured-guide"].exists)
        XCTAssertTrue(app.buttons["guide-wash-your-first-load"].waitForExistence(timeout: 5))
        shot("phone-search")
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shot("phone-settings")
        app.buttons["Done"].tap()
        app.buttons["guide-wash-your-first-load"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        app.buttons["remind-guide"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForExistence(timeout: 5))
        app.buttons["Tomorrow"].tap()
        shot("phone-reminder")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForNonExistence(timeout: 5))
    }
    func testDarkAndAccessibilityLayouts() {
        launch(["--qa-dark"])
        shot("phone-dark")
        app.terminate()
        launch(["--qa-dark", "--qa-accessibility-text"])
        shot("phone-accessibility-dark")
        let featured = app.buttons["featured-guide"].firstMatch
        reveal(featured, in: app.scrollViews["guide-collection"])
        featured.tap()
        let reader = app.scrollViews["guide-reader"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        shot("phone-reader-accessibility-dark")
        let step = app.buttons["step-repair-a-short-loose-cotton-hem-inspect-fold"]
        reveal(step, in: reader)
        shot("phone-steps-accessibility-dark")
    }
    func testTabletAdaptiveSelectionAndSearch() throws {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Tablet layout check") }
        XCUIDevice.shared.orientation = .portrait
        launch()
        let search = app.textFields["guide-search"]
        search.tap(); search.typeText("backstitch\n")
        let guide = app.buttons["guide-repair-a-short-loose-cotton-hem"].firstMatch
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        shot("tablet-portrait-reader")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["guide-search"].value as? String, "backstitch")
        shot("tablet-wide-reader")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["guide-search"].value as? String, "backstitch")
        shot("tablet-returned-portrait-reader")
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shot("tablet-settings")
        app.buttons["Done"].tap()
        #endif
    }

}
