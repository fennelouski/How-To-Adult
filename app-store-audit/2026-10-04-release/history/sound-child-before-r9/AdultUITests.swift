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
        evidence("21-native-settings-apps-route", settings)
        let apps = settings.buttons.matching(identifier: "com.apple.settings.apps")
        for index in 0..<7 {
            evidence("21b-observed-apps-control-" + String(index), settings)
            guard apps.count <= 1 else {
                throw NSError(domain: "AdultQAAmbiguousNativeAppsControl", code: 1)
            }
            if apps.count == 1 && apps.firstMatch.isHittable { break }
            if index < 6 { settings.swipeUp() }
        }
        guard apps.count == 1 && apps.firstMatch.isHittable else {
            throw NSError(domain: "AdultQAObserveNativeAppsControl", code: 1)
        }
        apps.firstMatch.tap()
        let appRow = try observedCell("How to Adult", "22-native-apps-list")
        appRow.tap()
        evidence("22b-native-how-to-adult-settings", settings)
        XCTAssertTrue(settings.navigationBars["How to Adult"].exists)
        let notifications = try observedCell("Notifications", "22c-native-app-notifications-control")
        notifications.tap()
        evidence("23-native-app-notification-controls", settings)
        let notificationBar = settings.navigationBars["Notifications"]
        XCTAssertTrue(notificationBar.exists)
        XCTAssertTrue(notificationBar.buttons["How to Adult"].exists)
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
        // Dismiss only a genuinely exposed unique popover control before Cancel.
        let regions = app.descendants(matching: .any).matching(identifier: "PopoverDismissRegion")
        if regions.count == 1 && regions.firstMatch.isHittable { regions.firstMatch.tap() }
        evidence("27-current-time-picker-dismissal-state", app)
        let cancel = app.buttons["Cancel"]
        guard cancel.exists && cancel.isHittable else {
            throw NSError(domain: "AdultQAObserveReminderCancel", code: 1)
        }
        cancel.tap()
        let cancelled = app.buttons["save-reminder"].waitForNonExistence(timeout: 5)
        evidence("28-reminder-cancelled-same-guide", app)
        XCTAssertTrue(cancelled)
        XCTAssertTrue(app.scrollViews["guide-reader"].exists)
        XCTAssertTrue(app.staticTexts["Wash a load of laundry"].exists)
        // No value edit, Save, scheduling or synthetic delivery.
    }

    func testRealReminderDeliveryAndTapRoute() throws {
        let title = "Wash a load of laundry"
        let body = "Your guide is ready when you are."
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var saved = false
        func evidence(_ name: String, _ nativeApp: XCUIApplication) {
            shot(name)
            let tree = XCTAttachment(string: nativeApp.debugDescription)
            tree.name = name + "-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        func record(_ name: String, _ details: [String: String]) {
            let data = try! JSONSerialization.data(withJSONObject: details, options: [.sortedKeys])
            let text = String(decoding: data, as: UTF8.self)
            print("ADULT_REAL_REMINDER " + name + " " + text)
            let attachment = XCTAttachment(string: text)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func normalized(_ value: String) -> String {
            String(value.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
        }
        defer {
            // Cleanup is a separate native private-QA action, never counted as notification routing.
            if saved {
                app.terminate()
                app.launch()
                if app.scrollViews["guide-collection"].waitForExistence(timeout: 10),
                   app.buttons["featured-guide"].exists {
                    app.buttons["featured-guide"].tap()
                    if app.scrollViews["guide-reader"].waitForExistence(timeout: 5),
                       app.buttons["remind-guide"].exists {
                        app.buttons["remind-guide"].tap()
                        _ = app.buttons["save-reminder"].waitForExistence(timeout: 5)
                        evidence("49-native-private-reminder-cleanup", app)
                        let remove = app.buttons["remove-reminder"]
                        if remove.exists && remove.isHittable {
                            remove.tap()
                            record("49-cleanup-outcome", ["action": "Removed still-future own reminder through native app control"])
                        } else if app.buttons["Cancel"].exists && app.buttons["Cancel"].isHittable {
                            app.buttons["Cancel"].tap()
                            record("49-cleanup-outcome", ["action": "No still-future native Remove control; cancelled editor, preserved expired/delivered evidence"])
                        }
                    }
                }
            }
            app.terminate()
        }
        app.buttons["featured-guide"].tap()
        XCTAssertTrue(app.scrollViews["guide-reader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].exists)
        app.buttons["remind-guide"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForExistence(timeout: 5))
        evidence("31-real-reminder-initial-date", app)
        XCTAssertFalse(app.buttons["remove-reminder"].exists)
        let calendar = Calendar.current
        let now = Date()
        let target = Date(timeIntervalSince1970: ceil(now.addingTimeInterval(240).timeIntervalSince1970 / 60) * 60)
        guard calendar.isDate(target, inSameDayAs: now) else {
            throw NSError(domain: "AdultQARealReminderDateBoundary", code: 1)
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        let hour24 = components.hour!
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let minute = components.minute!
        let period = hour24 < 12 ? "AM" : "PM"
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US")
        dateFormat.calendar = calendar
        dateFormat.timeZone = calendar.timeZone
        dateFormat.dateFormat = "MMM d, yyyy"
        let expectedDate = dateFormat.string(from: target)
        let expectedTime = String(format: "%d:%02d %@", hour12, minute, period)
        let compact = app.datePickers
        guard compact.count == 1, compact.firstMatch.buttons[expectedDate].exists else {
            throw NSError(domain: "AdultQARealReminderActualDateMismatch", code: 1)
        }
        let time = compact.firstMatch.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,2}:[0-9]{2}.*"))
        guard time.count == 1 && time.firstMatch.isHittable else {
            throw NSError(domain: "AdultQARealReminderActualTimeControl", code: 1)
        }
        time.firstMatch.tap()
        evidence("32-real-reminder-observed-wheels", app)
        let wheels = app.pickerWheels
        guard wheels.count == 3,
              let initialHour = wheels.element(boundBy: 0).value as? String,
              let initialMinute = wheels.element(boundBy: 1).value as? String,
              let initialPeriod = wheels.element(boundBy: 2).value as? String,
              initialHour.contains("o’clock"), initialMinute.contains("minute"),
              ["AM", "PM"].contains(initialPeriod) else {
            throw NSError(domain: "AdultQARealReminderActualWheelForms", code: 1)
        }
        // Set minutes first so reducing the default +1-hour selection does not transiently cross the minimum date.
        let minuteValue = String(format: "%02d", minute) // Actual selectable options00…59 from r7 failure.
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: minuteValue)
        evidence("33-real-reminder-minute-selection", app)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: String(hour12))
        if (wheels.element(boundBy: 2).value as? String) != period {
            wheels.element(boundBy: 2).adjust(toPickerWheelValue: period)
        }
        evidence("34-real-reminder-selected-time", app)
        let actualHour = wheels.element(boundBy: 0).value as? String ?? ""
        let actualMinute = wheels.element(boundBy: 1).value as? String ?? ""
        let actualPeriod = wheels.element(boundBy: 2).value as? String ?? ""
        guard actualHour == "\(hour12) o’clock",
              Int(actualMinute.prefix(2)) == minute, actualPeriod == period else {
            throw NSError(domain: "AdultQARealReminderWheelValueMismatch", code: 1)
        }
        let dismissal = app.buttons.matching(identifier: "PopoverDismissRegion")
        guard dismissal.count == 1 && dismissal.firstMatch.isHittable else {
            throw NSError(domain: "AdultQARealReminderActualPopoverDismissal", code: 1)
        }
        dismissal.firstMatch.tap()
        let selectedTime = app.datePickers.firstMatch.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,2}:[0-9]{2}.*"))
        guard selectedTime.count == 1,
              normalized(selectedTime.firstMatch.label) == normalized(expectedTime),
              app.datePickers.firstMatch.buttons[expectedDate].exists,
              target.timeIntervalSinceNow >= 120 else {
            evidence("35-real-reminder-date-guard-failure", app)
            throw NSError(domain: "AdultQARealReminderCompactDateMismatch", code: 1)
        }
        let sound = app.switches.matching(NSPredicate(format: "label == %@", "Play a sound"))
        guard sound.count == 1 && sound.firstMatch.isHittable,
              let soundValue = sound.firstMatch.value as? String,
              ["0", "1"].contains(soundValue) else {
            throw NSError(domain: "AdultQARealReminderActualSoundSwitch", code: 1)
        }
        if soundValue == "1" { sound.firstMatch.tap() }
        XCTAssertEqual(sound.firstMatch.value as? String, "0")
        let iso = ISO8601DateFormatter()
        record("36-real-reminder-before-save", ["targetUTC": iso.string(from: target),
            "calendarTimeZone": calendar.timeZone.identifier, "dateLabel": expectedDate,
            "timeLabel": selectedTime.firstMatch.label, "sound": "0",
            "secondsRemaining": String(target.timeIntervalSinceNow), "guideID": "wash-your-first-load"])
        evidence("36-real-reminder-before-save", app)
        app.buttons["save-reminder"].tap() // Exactly one genuine scheduling attempt.
        saved = app.buttons["save-reminder"].waitForNonExistence(timeout: 10)
        evidence("37-real-reminder-save-result", app)
        XCTAssertTrue(saved)
        XCTAssertTrue(app.scrollViews["guide-reader"].exists)
        app.buttons["remind-guide"].tap()
        XCTAssertTrue(app.buttons["remove-reminder"].waitForExistence(timeout: 5))
        evidence("38-real-reminder-pending-record", app)
        XCTAssertTrue(app.datePickers.firstMatch.buttons[expectedDate].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["save-reminder"].waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Reminders"].tap()
        let pending = app.buttons["guide-wash-your-first-load"]
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        evidence("39-real-reminders-list", app)
        app.tabBars.buttons["Guides"].tap()
        goHome()
        XCTAssertTrue(app.scrollViews["guide-collection"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews["guide-reader"].exists)
        evidence("40-real-reminder-away-from-reader", app)
        XCUIDevice.shared.press(.home)
        let background = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.app.state == .runningBackground || self.app.state == .notRunning
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [background], timeout: 5), .completed)
        record("41-real-reminder-background-wait", ["targetUTC": iso.string(from: target),
            "startedUTC": iso.string(from: Date()), "appState": String(app.state.rawValue)])
        evidence("41-real-springboard-before-delivery", springboard)
        let combinedPredicate = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, body)
        let delivered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            springboard.descendants(matching: .any).matching(combinedPredicate).count > 0 ||
            springboard.staticTexts.matching(NSPredicate(format: "label == %@", body)).count > 0
        }, object: nil)
        let maximumWait = min(400, max(1, target.timeIntervalSinceNow + 90))
        let observedDelivery = XCTWaiter.wait(for: [delivered], timeout: maximumWait) == .completed
        evidence("42-real-native-notification-observation", springboard)
        record("42-real-native-notification-observation", ["targetUTC": iso.string(from: target),
            "observedUTC": iso.string(from: Date()), "foundNativeContent": String(observedDelivery)])
        guard observedDelivery else {
            throw NSError(domain: "AdultQARealNativeNotificationNotObserved", code: 1)
        }
        let ownContainers = springboard.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS[c] %@", title, body, "How to Adult"))
        let ownHits = ownContainers.allElementsBoundByIndex.filter { $0.isHittable }
        let targetElement: XCUIElement
        if ownHits.count == 1 {
            targetElement = ownHits[0]
        } else if ownHits.isEmpty {
            let titleHits = springboard.staticTexts.matching(NSPredicate(format: "label == %@", title)).allElementsBoundByIndex.filter { $0.isHittable }
            let bodyHits = springboard.staticTexts.matching(NSPredicate(format: "label == %@", body)).allElementsBoundByIndex.filter { $0.isHittable }
            let ownNameHits = springboard.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "How to Adult")).allElementsBoundByIndex.filter { $0.isHittable }
            guard titleHits.count == 1 && bodyHits.count == 1 && ownNameHits.count == 1 else {
                throw NSError(domain: "AdultQARealNativeNotificationAmbiguousTarget", code: 1)
            }
            targetElement = bodyHits[0]
        } else {
            throw NSError(domain: "AdultQARealNativeNotificationAmbiguousTarget", code: 1)
        }
        record("43-real-native-notification-tap-target", ["elementType": String(targetElement.elementType.rawValue),
            "identifier": targetElement.identifier, "label": targetElement.label,
            "frame": String(describing: targetElement.frame)])
        targetElement.tap() // No icon, URL/deep link, synthetic push, recipient or destination.
        let foreground = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.state == .runningForeground }, object: nil)
        let foregroundReady = XCTWaiter.wait(for: [foreground], timeout: 10) == .completed
        let readerReady = app.scrollViews["guide-reader"].waitForExistence(timeout: 10)
        evidence("44-real-notification-routed-guide", app)
        XCTAssertTrue(foregroundReady)
        XCTAssertTrue(readerReady)
        XCTAssertTrue(app.staticTexts[title].exists)
        record("44-real-notification-routed-guide", ["foreground": String(foregroundReady),
            "guideReader": String(readerReady), "title": title,
            "iconOrDeepLinkLaunch": "false", "syntheticNotification": "false"])
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
