import XCTest
#if os(iOS)
import UIKit
#endif

/// Real navigation and persistence checks on the bundled catalog in an isolated private-QA library.
/// Never grants notification or other permissions.
@MainActor final class FieldnotesUITests: XCTestCase {
    private var app: XCUIApplication!
    private let sessionID = UUID()
    private let hem = "repair-a-short-loose-cotton-hem"

    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            app = XCUIApplication()
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom != .pad { XCUIDevice.shared.orientation = .portrait }
            #endif
        }
    }

    // MARK: Helpers

    private func launch(_ arguments: [String] = []) {
        app.launchEnvironment["ADULT_QA_BLANK_HOST"] = "0"
        app.launchArguments = ["--adult-private-qa=" + sessionID.uuidString, "--qa-library"] + arguments
        app.launch()
        XCTAssertTrue(element("now-screen").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["adult-private-qa-marker"].firstMatch.label.contains(sessionID.uuidString))
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
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private var reader: XCUIElement { element("guide-reader") }

    private func reveal(_ target: XCUIElement, in scroll: XCUIElement, up: Bool = true) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            if up { scroll.swipeUp() } else { scroll.swipeDown() }
        }
        XCTAssertTrue(target.isHittable)
    }

    private func selectSection(_ name: String) {
        #if os(iOS)
        if app.tabBars.buttons[name].exists { app.tabBars.buttons[name].tap(); return }
        #endif
        let row = app.buttons[name].firstMatch
        if row.exists && row.isHittable { row.tap() } else { app.staticTexts[name].firstMatch.tap() }
    }

    /// Pops the Explore stack back to the tile grid.
    private func exploreRoot() {
        selectSection("Explore")
        for _ in 0..<3 where !element("category-home").exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }
        XCTAssertTrue(element("category-home").waitForExistence(timeout: 5))
    }

    /// Explore ▸ Home ▸ (optional sub-area) ▸ guide, landing on its overview.
    private func openGuide(_ id: String, category: String = "home", subArea: String? = nil) {
        exploreRoot()
        element("category-" + category).tap()
        if let subArea {
            let chip = element("subarea-" + subArea)
            XCTAssertTrue(chip.waitForExistence(timeout: 5))
            chip.tap()
        }
        // Topic grids are lazy: at large text sizes a card exists only once scrolled near.
        let card = element("guide-" + id)
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<12 where !(card.exists && card.isHittable) { scroll.swipeUp() }
        XCTAssertTrue(card.exists)
        card.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        showOverview()
    }

    /// A started guide resumes at its first open step; jump to the overview when a test needs it.
    private func showOverview() {
        let overview = app.buttons["Overview"].firstMatch
        if overview.waitForExistence(timeout: 3) { overview.tap() }
        _ = element("start-guide").waitForExistence(timeout: 3)
    }

    /// The step page's own controls; the pager keeps neighbouring pages alive.
    private func onStep(_ stepID: String, _ control: String) -> XCUIElement {
        element("step-page-" + stepID).descendants(matching: .button).matching(identifier: control).firstMatch
    }

    /// Opens the guide's overflow menu if needed and returns one of its items.
    private func menuItem(_ id: String) -> XCUIElement {
        #if os(macOS)
        let item = app.menuItems[id].firstMatch
        if item.exists && item.isHittable { return item }
        let more = app.menuButtons["guide-more"].firstMatch
        (more.exists ? more : app.buttons["guide-more"].firstMatch).click()
        #else
        let item = app.buttons[id].firstMatch
        if item.exists && item.isHittable { return item }
        app.buttons["guide-more"].firstMatch.tap()
        #endif
        _ = item.waitForExistence(timeout: 5)
        return item
    }

    private func pause() { Thread.sleep(forTimeInterval: 0.9) } // lets the 350 ms auto-advance settle

    // MARK: Flows

    func testCarouselKnownFavoritesPassportAndArt() {
        launch()
        shot("01-now-start")
        exploreRoot()
        shot("02-explore")
        element("category-home").tap()
        XCTAssertTrue(element("subarea-home.laundry").waitForExistence(timeout: 5))
        element("subarea-home.laundry").tap()
        XCTAssertFalse(element("guide-clean-a-bathroom").exists, "Sub-area chip filters the topic")
        shot("03-topic-subarea")
        element("guide-" + hem).tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(element("card-supplies").exists && element("card-cautions").exists && element("card-sources").exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Do not sew clothing while wearing it")).firstMatch.exists)
        shot("04-overview")

        // Fieldnotes art: full size and zoom from the overview.
        let fullSize = app.buttons["View full size"].firstMatch
        if fullSize.waitForExistence(timeout: 10) {
            reveal(fullSize, in: element("step-page-overview").exists ? element("step-page-overview") : reader, up: true)
            fullSize.tap()
            XCTAssertTrue(app.navigationBars["Illustration"].waitForExistence(timeout: 5))
            app.buttons["Zoom in"].tap()
            shot("05-full-size-art")
            app.buttons["Done"].tap()
        } else {
            XCTFail("Hero illustration did not load; artwork is fetched from the catalog service")
        }

        let save = app.buttons["save-guide"].firstMatch
        if save.label == "Favorite" { save.tap() }
        XCTAssertEqual(save.label, "Remove from favorites")

        element("start-guide").tap()
        XCTAssertTrue(element("done-step").waitForExistence(timeout: 5))
        shot("06-step-1")
        element("done-step").tap(); pause()                  // step 1 done
        element("know-step").tap(); pause()                  // step 2 already known
        onStep(hem + "-sew-backstitch", "favorite-step").tap() // heart step 3
        shot("07-step-3-favorite")
        element("skip-step").tap(); pause()                  // leave step 3 open
        #if os(iOS)
        reader.swipeRight(); pause()                         // swipe back to step 3
        #endif
        XCTAssertTrue(element("page-indicator").exists)
        shot("08-progress")

        selectSection("Now")
        let continueCard = element("continue-" + hem)
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5), "A started guide appears in Now")
        XCTAssertTrue(element("favorite-step-" + hem + "-sew-backstitch").exists)
        shot("09-now-continue")
        continueCard.tap()
        XCTAssertTrue(element("done-step").waitForExistence(timeout: 5), "Resumes at the first open step")
        for _ in 0..<3 { element("done-step").tap(); pause() }
        XCTAssertTrue(element("finish-stamp").waitForExistence(timeout: 5))
        shot("10-finish")

        menuItem("menu-ask-ai").tap()
        XCTAssertTrue(element("ask-ai-copied").waitForExistence(timeout: 5))
        shot("11-ask-ai")
        app.buttons["Done"].firstMatch.tap()

        selectSection("Passport")
        XCTAssertTrue(element("passport-page-home").waitForExistence(timeout: 5))
        shot("12-passport")

        exploreRoot()
        element("filter-favorites").tap()
        XCTAssertTrue(element("guide-" + hem).waitForExistence(timeout: 5))
        shot("13-favorites-filter")
        element("filter-favorites").tap()
        let search = app.textFields["guide-search"]
        search.tap(); search.typeText("laundry\n")
        let wash = element("guide-wash-your-first-load")
        XCTAssertTrue(wash.waitForExistence(timeout: 5))
        shot("14-search")
        wash.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        menuItem("menu-know-guide").tap()
        XCTAssertTrue(app.staticTexts["Already known"].waitForExistence(timeout: 5))
        shot("15-known")
        menuItem("remind-guide").tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForExistence(timeout: 5))
        app.buttons["Tomorrow"].tap()
        shot("16-reminder")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForNonExistence(timeout: 5))
        selectSection("Passport")
        app.buttons["open-settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shot("17-settings")
        app.buttons["Done"].firstMatch.tap()

        // Cold relaunch keeps marks, favorites and known state.
        app.terminate()
        launch()
        XCTAssertFalse(element("continue-" + hem).exists, "Finished guide left Now")
        XCTAssertTrue(element("favorite-step-" + hem + "-sew-backstitch").exists)
        selectSection("Passport")
        XCTAssertTrue(element("passport-page-home").waitForExistence(timeout: 5))
        let finished = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND value == %@", "Repair a short loose cotton hem", "Finished")).firstMatch
        let known = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND value == %@", "Wash a load of laundry", "Already known")).firstMatch
        for _ in 0..<6 where !(finished.exists && known.exists) { element("passport-screen").swipeUp() }
        XCTAssertTrue(finished.exists || app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", "Finished")).count > 0)
        XCTAssertTrue(known.exists, "Known guide shows a distinct stamp after relaunch")
    }

    func testPrivateNotesAndRating() {
        launch()
        openGuide(hem, subArea: "home.laundry")
        app.buttons["Finish"].firstMatch.tap()
        let rating = app.buttons["Rate 4 out of 5"]
        XCTAssertTrue(rating.waitForExistence(timeout: 5))
        rating.tap()
        XCTAssertEqual(rating.value as? String, "Selected")
        let notes = app.buttons["guide-personal-notes"]
        notes.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText("Private QA note: use matching thread.")
        shot("notes-editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Private QA note: use matching thread."].waitForExistence(timeout: 5))
        shot("notes-saved")
        notes.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(" Unsaved edit.")
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard changes"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.staticTexts["Private QA note: use matching thread."].waitForExistence(timeout: 5))
    }

    func testDarkAndAccessibilityLayouts() {
        launch(["--qa-dark"])
        shot("dark-now")
        app.terminate()
        launch(["--qa-dark", "--qa-accessibility-text"])
        shot("dark-large-now")
        openGuide(hem, subArea: "home.laundry")
        shot("dark-large-overview")
        let source = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Backstitch on a Loose Hem")).firstMatch
        for _ in 0..<10 where !(source.exists && source.isHittable) { reader.swipeUp() }
        XCTAssertTrue(source.exists, "Sources stay reachable at the largest text size")
        shot("dark-large-sources")
        element("start-guide").tap()
        XCTAssertTrue(element("done-step").waitForExistence(timeout: 5))
        XCTAssertTrue(element("done-step").isHittable, "Step actions stay reachable at accessibility sizes")
        shot("dark-large-step")
    }

    func testTabletAdaptiveSelectionAndSearch() throws {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Tablet layout check") }
        XCUIDevice.shared.orientation = .portrait
        launch()
        exploreRoot()
        let search = app.textFields["guide-search"]
        search.tap(); search.typeText("backstitch\n")
        let guide = element("guide-" + hem)
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        shot("tablet-portrait-reader")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(reader.waitForExistence(timeout: 5), "Reader survives the switch to the wide layout")
        shot("tablet-wide-reader")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.textFields["guide-search"].value as? String, "backstitch", "Search survives rotation")
        shot("tablet-returned-search")
        app.buttons["open-settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shot("tablet-settings")
        app.buttons["Done"].firstMatch.tap()
        #endif
    }
}
