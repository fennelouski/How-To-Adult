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

    func testNativeShareAndNotificationDenialRecovery() throws {
        defer { app.terminate() }
        app.buttons["featured-guide"].tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        let share = app.buttons["Share…"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        let chooser = app.otherElements["ActivityListView"].firstMatch
        let chooserReady = chooser.waitForExistence(timeout: 10)
        shot("14-actual-native-share")
        let shareTree = XCTAttachment(string: app.debugDescription)
        shareTree.name = "14-actual-native-share-tree"
        shareTree.lifetime = .keepAlways
        add(shareTree)
        XCTAssertTrue(chooserReady)
        // Observe a real dismissal control. No share recipient or destination is selected.
        let dismissal = chooser.buttons["header.closeButton"]
        guard dismissal.exists && dismissal.isHittable else {
            throw NSError(domain: "AdultQAObserveNativeShareDismissal", code: 1)
        }
        dismissal.tap()
        XCTAssertTrue(chooser.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["guide-reader"].exists)
        app.buttons["remind-guide"].tap()
        let pickerReady = app.buttons["save-reminder"].waitForExistence(timeout: 5)
        shot("15-actual-reminder-picker")
        let pickerTree = XCTAttachment(string: app.debugDescription)
        pickerTree.name = "15-actual-reminder-picker-tree"
        pickerTree.lifetime = .keepAlways
        add(pickerTree)
        XCTAssertTrue(pickerReady)
        app.buttons["save-reminder"].tap()
        #if os(iOS)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.alerts.buttons["Don’t Allow"].firstMatch
        let asciiDeny = springboard.alerts.buttons["Don't Allow"].firstMatch
        let permissionReady = deny.waitForExistence(timeout: 5) || asciiDeny.exists
        shot("15b-actual-notification-permission")
        let permissionTree = XCTAttachment(string: springboard.debugDescription)
        permissionTree.name = "15b-actual-notification-permission-tree"
        permissionTree.lifetime = .keepAlways
        add(permissionTree)
        guard permissionReady else {
            throw NSError(domain: "AdultQAFreshOwnedDeviceNotificationPermissionRequired", code: 1)
        }
        if deny.exists { deny.tap() } else { asciiDeny.tap() }
        #endif
        let explanation = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Notifications are turned off")).firstMatch
        let denialReady = explanation.waitForExistence(timeout: 8)
        shot("16-notification-denied-safe-recovery")
        let denialTree = XCTAttachment(string: app.debugDescription)
        denialTree.name = "16-notification-denied-safe-recovery-tree"
        denialTree.lifetime = .keepAlways
        add(denialTree)
        XCTAssertTrue(denialReady)
        XCTAssertTrue(app.buttons["save-reminder"].exists)
        XCTAssertFalse(app.buttons["remove-reminder"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
    }

    #if os(iOS)
    func testNotificationDeniedRecoveryTail() throws {
        defer { app.terminate() }
        app.buttons["featured-guide"].tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        app.buttons["remind-guide"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForExistence(timeout: 5))
        // The private device was genuinely denied through the r3 system prompt.
        // Save now returns the recorded app alert without permission reset or re-prompt.
        app.buttons["save-reminder"].tap()
        let deniedAlert = app.alerts["Couldn’t finish"].firstMatch
        let alertReady = deniedAlert.waitForExistence(timeout: 8)
        shot("17-already-denied-native-alert")
        let alertTree = XCTAttachment(string: app.debugDescription)
        alertTree.name = "17-already-denied-native-alert-tree"
        alertTree.lifetime = .keepAlways
        add(alertTree)
        XCTAssertTrue(alertReady)
        let explanation = deniedAlert.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Notifications are turned off")).firstMatch
        XCTAssertTrue(explanation.exists)
        let okay = deniedAlert.buttons["OK"]
        XCTAssertTrue(okay.exists && okay.isHittable)
        okay.tap()
        let alertClosed = deniedAlert.waitForNonExistence(timeout: 5)
        shot("18-denied-alert-closed-state")
        let returnedTree = XCTAttachment(string: app.debugDescription)
        returnedTree.name = "18-denied-alert-closed-state-tree"
        returnedTree.lifetime = .keepAlways
        add(returnedTree)
        XCTAssertTrue(alertClosed)
        let save = app.buttons["save-reminder"]
        // Observe the native state after OK; iOS may retain or dismiss the picker.
        if !save.exists {
            XCTAssertTrue(app.scrollViews["guide-reader"].exists)
            let remind = app.buttons["remind-guide"]
            XCTAssertTrue(remind.exists && remind.isHittable)
            remind.tap()
        }
        let reopened = save.waitForExistence(timeout: 5)
        shot("19-denied-reminder-available")
        let reopenedTree = XCTAttachment(string: app.debugDescription)
        reopenedTree.name = "19-denied-reminder-available-tree"
        reopenedTree.lifetime = .keepAlways
        add(reopenedTree)
        XCTAssertTrue(reopened)
        XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(app.buttons["remove-reminder"].exists)
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.exists && cancel.isHittable)
        cancel.tap()
        let returned = app.scrollViews["guide-reader"].waitForExistence(timeout: 5)
        shot("20-denied-recovery-cancel-same-reader")
        let cancelledTree = XCTAttachment(string: app.debugDescription)
        cancelledTree.name = "20-denied-recovery-cancel-same-reader-tree"
        cancelledTree.lifetime = .keepAlways
        add(cancelledTree)
        XCTAssertTrue(returned)
        XCTAssertTrue(app.staticTexts["Wash a load of laundry"].exists)
    }
    func testNativeNotificationSettingsAndPickerReconnaissance() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        defer { settings.terminate(); app.terminate() }
        func evidence(_ name: String, _ nativeApp: XCUIApplication) {
            shot(name)
            let tree = XCTAttachment(string: nativeApp.debugDescription)
            tree.name = name + "-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        func observedCell(_ label: String, _ context: String) throws -> XCUIElement {
            let cells = settings.cells.containing(.staticText, identifier: label)
            for index in 0..<7 {
                evidence(context + "-" + String(index), settings)
                guard cells.count <= 1 else {
                    throw NSError(domain: "AdultQAAmbiguousNativeSettingsCell", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: label])
                }
                if cells.count == 1 && cells.firstMatch.isHittable { return cells.firstMatch }
                if index < 6 { settings.swipeUp() }
            }
            throw NSError(domain: "AdultQAObserveNativeSettingsCell", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: label])
        }
        app.terminate()
        settings.launch()
        let notifications = try observedCell("Notifications", "21-native-settings-root")
        notifications.tap()
        let appRow = try observedCell("How to Adult", "22-native-notification-list")
        appRow.tap()
        evidence("23-native-app-notification-controls", settings)
        XCTAssertTrue(settings.navigationBars["How to Adult"].exists)
        let switches = settings.switches.matching(NSPredicate(format: "label == %@", "Allow Notifications"))
        guard switches.count == 1 else {
            throw NSError(domain: "AdultQAObserveNativeAllowNotifications", code: 1)
        }
        let allow = switches.firstMatch
        guard allow.isHittable, let prior = allow.value as? String, prior == "0" || prior == "1" else {
            throw NSError(domain: "AdultQAObserveNativeNotificationSwitchValue", code: 1)
        }
        if prior == "0" { allow.tap() }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: allow)
        let enabledReady = XCTWaiter.wait(for: [enabled], timeout: 5) == .completed
        evidence("24-native-notifications-enabled", settings)
        XCTAssertTrue(enabledReady)
        settings.terminate()
        app.launch()
        XCTAssertTrue(app.scrollViews["guide-collection"].waitForExistence(timeout: 15))
        app.buttons["featured-guide"].tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        app.buttons["remind-guide"].tap()
        let pickerReady = app.buttons["save-reminder"].waitForExistence(timeout: 5)
        evidence("25-current-reminder-date-controls", app)
        XCTAssertTrue(pickerReady)
        XCTAssertFalse(app.buttons["remove-reminder"].exists)
        let datePickers = app.datePickers
        guard datePickers.count == 1 else {
            throw NSError(domain: "AdultQAObserveUniqueNativeDatePicker", code: 1)
        }
        // This matches the actual r3 child time label, without hard-coding its changing value.
        let timeControls = datePickers.firstMatch.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-9]{1,2}:[0-9]{2}.*"))
        guard timeControls.count == 1, timeControls.firstMatch.isHittable else {
            throw NSError(domain: "AdultQAObserveNativeTimeControl", code: 1)
        }
        timeControls.firstMatch.tap()
        evidence("26-expanded-native-time-picker", app)
        // Reconnaissance stops here. No value edit, Save, scheduling or synthetic delivery.
    }
    #endif

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
