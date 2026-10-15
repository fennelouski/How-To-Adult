import Foundation
import XCTest

@MainActor final class AdultAssistantUITests: XCTestCase {
    func testPrivateAssistantComposerPlanSettingsAndReturn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let sessionID = UUID()
        app.launchArguments = ["--adult-private-qa=" + sessionID.uuidString, "--qa-assistant"]
        app.launchEnvironment["ADULT_QA_BLANK_HOST"] = "0"
        app.launch()
        defer { app.terminate() }

        let marker = app.staticTexts["adult-private-qa-marker"].firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 12))
        XCTAssertTrue(marker.label.contains(sessionID.uuidString), "The app must confirm this exact private session before any interaction.")

        let composer = app.textViews["assistant-goal"].firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 12))
        capture("01-private-assistant-composer", app: app, sessionID: sessionID, targets: [composer])
        try requireVisible(composer, app: app)
        XCTAssertEqual(composer.label, "Task for your assistant")
        XCTAssertTrue(app.buttons["assistant-connect"].exists)

        // On iPad the same saved plan can also be present in the native content sidebar.
        let savedPlan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "A calmer Sunday")).firstMatch
        try reveal(savedPlan, app: app, direction: .up)
        capture("02-private-saved-plan-target", app: app, sessionID: sessionID, targets: [savedPlan])
        savedPlan.tap()

        let content = app.scrollViews["assistant-screen"].firstMatch
        XCTAssertTrue(content.exists)
        let title = content.staticTexts["A calmer Sunday"].firstMatch
        let calendarAction = content.staticTexts["Make room for a weekly reset"].firstMatch
        XCTAssertTrue(calendarAction.waitForExistence(timeout: 8))
        // Selecting a saved plan may preserve the scroll offset; use only native scrolling.
        try reveal(title, app: app, direction: .down)
        try requireVisible(calendarAction, app: app)
        let addCalendar = app.buttons["Add to Calendar"].firstMatch
        XCTAssertTrue(addCalendar.exists)
        XCTAssertFalse(addCalendar.isEnabled, "Private QA must not permit a native scheduling write.")
        capture("03-private-assistant-plan-calendar", app: app, sessionID: sessionID,
                targets: [title, calendarAction, addCalendar])

        let settings = app.buttons["assistant-settings"].firstMatch
        try requireVisible(settings, app: app)
        settings.tap()
        let settingsTitle = app.navigationBars["Assistant settings"].firstMatch
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 8))
        let connection = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Your AI")).firstMatch
        let done = settingsTitle.buttons["Done"].firstMatch
        capture("04-private-assistant-settings", app: app, sessionID: sessionID, targets: [connection, done])
        try requireVisible(connection, app: app)
        try requireVisible(done, app: app)
        done.tap()
        XCTAssertTrue(settingsTitle.waitForNonExistence(timeout: 8))

        let anotherTask = app.buttons["assistant-another-task"].firstMatch
        try reveal(anotherTask, app: app, direction: .up)
        capture("05-private-another-task-target", app: app, sessionID: sessionID, targets: [anotherTask])
        XCTAssertTrue(anotherTask.label.contains("Another task"))
        anotherTask.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        try reveal(composer, app: app, direction: .down)
        if let text = composer.value as? String { XCTAssertTrue(text.isEmpty) }
        capture("06-private-assistant-return-composer", app: app, sessionID: sessionID, targets: [composer])
        try requireVisible(composer, app: app)
        XCTAssertTrue(app.buttons["assistant-connect"].exists)
    }

    private enum ScrollDirection { case up, down }

    private func reveal(_ target: XCUIElement, app: XCUIApplication, direction: ScrollDirection) throws {
        guard target.waitForExistence(timeout: 5) else {
            captureFailure("missing-target", app: app)
            throw NSError(domain: "AdultAssistantQA.MissingTarget", code: 1)
        }
        let scroll = app.scrollViews["assistant-screen"].firstMatch
        for _ in 0..<5 {
            let window = app.windows.firstMatch.frame
            if target.isHittable && window.contains(target.frame) { return }
            guard scroll.exists else { break }
            switch direction {
            case .up: scroll.swipeUp()
            case .down: scroll.swipeDown()
            }
        }
        captureFailure("target-not-visible-after-bounded-native-scroll", app: app)
        try requireVisible(target, app: app)
    }

    private func requireVisible(_ target: XCUIElement, app: XCUIApplication) throws {
        guard target.exists else {
            captureFailure("required-target-absent", app: app)
            throw NSError(domain: "AdultAssistantQA.MissingTarget", code: 2)
        }
        let frame = target.frame
        let window = app.windows.firstMatch.frame
        guard !frame.isEmpty, !frame.isInfinite, !frame.isNull, window.contains(frame), target.isHittable else {
            captureFailure("required-target-outside-visible-window", app: app)
            throw NSError(domain: "AdultAssistantQA.TargetVisibility", code: 1)
        }
    }

    private func capture(_ name: String, app: XCUIApplication, sessionID: UUID, targets: [XCUIElement]) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-native-tree"
        tree.lifetime = .keepAlways
        add(tree)
        let observed = targets.map { target -> [String: Any] in
            guard target.exists else { return ["exists": false] }
            let frame = target.frame
            return ["exists": true, "identifier": target.identifier, "label": target.label,
                    "type": target.elementType.rawValue, "hittable": target.isHittable,
                    "enabled": target.isEnabled,
                    "frame": ["x": Double(frame.minX), "y": Double(frame.minY),
                              "width": Double(frame.width), "height": Double(frame.height)]]
        }
        let record: [String: Any] = ["privateSessionID": sessionID.uuidString, "targets": observed,
                                     "qualification": "Actual AX bounds and screenshots; AX labels alone do not prove rendered text is untruncated."]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) {
            let bounds = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            bounds.name = name + "-actual-bounds"
            bounds.lifetime = .keepAlways
            add(bounds)
        }
    }

    private func captureFailure(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-native-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
