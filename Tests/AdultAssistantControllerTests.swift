import Foundation
import XCTest
@testable import HowToAdult

final class AdultAssistantControllerTests: XCTestCase {
    private func draftAction(kind: String, date: Date? = nil, duration: Int? = nil) -> [String: Any] {
        let scheduledAt: Any
        if let date { scheduledAt = ISO8601DateFormatter().string(from: date) }
        else { scheduledAt = NSNull() }
        let durationMinutes: Any
        if let duration { durationMinutes = duration }
        else { durationMinutes = NSNull() }
        return ["kind": kind, "title": "Laundry", "details": "Check the care label.",
                "scheduledAt": scheduledAt, "durationMinutes": durationMinutes, "repeatRule": "none",
                "items": [], "query": NSNull()]
    }

    private func providerResponse(_ actions: [[String: Any]]) throws -> Data {
        let draft = try JSONSerialization.data(withJSONObject: [
            "title": "A calmer week", "summary": "Make time for laundry.", "actions": actions
        ])
        return try JSONSerialization.data(withJSONObject: ["status": "completed", "output": [
            ["type": "message", "role": "assistant", "content": [
                ["type": "output_text", "text": String(decoding: draft, as: UTF8.self), "annotations": []]
            ]]
        ]])
    }

    @MainActor private func withFixture(response: Data, held: Bool = false,
                                        body: @MainActor (AdultControllerFixture) async throws -> Void) async throws {
        let fixture = try AdultControllerFixture(response: response, held: held)
        defer { fixture.cleanup() }
        try await body(fixture)
    }

    @MainActor private func diskArchive(_ fixture: AdultControllerFixture) throws -> AdultAssistantArchive {
        try AdultAssistantArchive.decode(Data(contentsOf: fixture.archiveURL))
    }

    @MainActor private func oldPlan() -> AdultAssistantPlan {
        AdultAssistantPlan(title: "Previously saved plan", summary: "Keep this pending until reviewed.",
            goal: "Do the laundry", provider: .openAI, actions: [
                AdultAssistantAction(kind: .calendar, title: "Old calendar draft", scheduledAt: Date().addingTimeInterval(7_200), durationMinutes: 30),
                AdultAssistantAction(kind: .reminder, title: "Old reminder draft", scheduledAt: Date().addingTimeInterval(7_200))
            ])
    }

    @MainActor private func waitForRequest(_ transport: AdultControllerTransport) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while clock.now < deadline {
            if await transport.requestCount() > 0 { return true }
            try await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    @MainActor private func waitForIdle(_ controller: AdultAssistantController) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while clock.now < deadline {
            if !controller.isWorking { return true }
            try await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    @MainActor func testAutomaticWritesSeeDurableRunningStateAndReceiptsSurviveReloadWithoutRepeat() async throws {
        let response = try providerResponse([
            draftAction(kind: "calendar", date: Date().addingTimeInterval(7_200), duration: 30),
            draftAction(kind: "reminder", date: Date().addingTimeInterval(10_800))
        ])
        try await withFixture(response: response) { fixture in
            var preferences = fixture.library.preferences
            preferences.autoCalendar = true
            preferences.autoReminders = true
            preferences.sound = false
            try fixture.library.savePreferences(preferences)
            var observedRunning: [UUID] = []
            fixture.system.beforeWrite = { request, _ in
                // Decode the file directly. Opening a second library here would correctly recover running as needsReview.
                let saved = try self.diskArchive(fixture)
                let plan = try XCTUnwrap(saved.plans.first)
                let action = try XCTUnwrap(plan.actions.first { $0.id == request.id })
                XCTAssertEqual(action.status, .running)
                XCTAssertNil(action.externalIdentifier)
                XCTAssertNil(action.localCompletion)
                XCTAssertEqual(fixture.controller.selectedPlanID, plan.id)
                XCTAssertEqual(fixture.controller.busyActionID, action.id)
                observedRunning.append(action.id)
            }
            let generated = try await fixture.controller.generate(goal: "Make time for laundry", guide: nil)
            XCTAssertEqual(observedRunning, generated.actions.map(\.id))
            XCTAssertEqual(fixture.system.attempts.map(\.service), [.calendar, .notifications])
            XCTAssertTrue(fixture.system.attempts.allSatisfy { !$0.request.sound })
            XCTAssertTrue(generated.actions.allSatisfy { $0.status == .completed && $0.externalIdentifier != nil && $0.error == nil })
            XCTAssertEqual(generated.actions[0].externalIdentifier, "fixture-calendar-" + generated.actions[0].id.uuidString)
            XCTAssertEqual(generated.actions[1].externalIdentifier, "AdultAssistant." + generated.actions[1].id.uuidString)
            let bytes = try Data(contentsOf: fixture.archiveURL)
            let reopened = AdultAssistantLibrary(directory: fixture.directory)
            XCTAssertEqual(reopened.plans, [generated])
            let second = fixture.controllerFor(library: reopened)
            for action in generated.actions { await second.apply(planID: generated.id, actionID: action.id) }
            XCTAssertEqual(fixture.system.attempts.count, 2)
            XCTAssertEqual(try Data(contentsOf: fixture.archiveURL), bytes)
            XCTAssertFalse(fixture.controller.isWorking)
            XCTAssertNil(fixture.controller.busyActionID)
        }
    }

    @MainActor func testEnablingAutomationRequestsPermissionOnlyAndNeverReplaysOldPlans() async throws {
        let response = try providerResponse([draftAction(kind: "calendar", date: Date().addingTimeInterval(7_200), duration: 30)])
        try await withFixture(response: response) { fixture in
            let original = self.oldPlan()
            try fixture.library.add(original)
            await fixture.controller.setAutomation(.calendar, enabled: true)
            await fixture.controller.setAutomation(.reminder, enabled: true)
            XCTAssertEqual(fixture.system.calendarPermissions, 1)
            XCTAssertEqual(fixture.system.notificationPermissions, 1)
            XCTAssertTrue(fixture.system.attempts.isEmpty)
            XCTAssertEqual(fixture.library.plans, [original])
            let saved = try self.diskArchive(fixture)
            XCTAssertTrue(saved.preferences.autoCalendar)
            XCTAssertTrue(saved.preferences.autoReminders)
            let generated = try await fixture.controller.generate(goal: "Plan another laundry session", guide: nil)
            XCTAssertEqual(fixture.system.attempts.map { $0.request.id }, generated.actions.map(\.id))
            XCTAssertEqual(fixture.library.plans.first { $0.id == original.id }, original)
            XCTAssertEqual(generated.actions.first?.status, .completed)
        }
    }

    @MainActor func testMissingDatesDurationsAndPastDraftsStayPendingWithoutNativeCalls() async throws {
        let response = try providerResponse([
            draftAction(kind: "calendar", duration: 30),
            draftAction(kind: "reminder"),
            draftAction(kind: "calendar", date: Date().addingTimeInterval(7_200)),
            draftAction(kind: "reminder", date: Date().addingTimeInterval(-120))
        ])
        try await withFixture(response: response) { fixture in
            var preferences = fixture.library.preferences
            preferences.autoCalendar = true
            preferences.autoReminders = true
            try fixture.library.savePreferences(preferences)
            let plan = try await fixture.controller.generate(goal: "Help me choose when to do laundry", guide: nil)
            XCTAssertEqual(plan.actions.count, 4)
            XCTAssertTrue(plan.actions.allSatisfy { $0.status == .pending && $0.externalIdentifier == nil })
            XCTAssertTrue(fixture.system.attempts.isEmpty)
            XCTAssertEqual(fixture.system.calendarPermissions, 0)
            XCTAssertEqual(fixture.system.notificationPermissions, 0)
            XCTAssertEqual(try self.diskArchive(fixture).plans, [plan])
            XCTAssertNil(fixture.controller.issue)
        }
    }

    @MainActor func testUncertainNativeWritePersistsNeedsReviewAndBlocksAnotherAttemptAfterReload() async throws {
        let response = try providerResponse([draftAction(kind: "calendar", date: Date().addingTimeInterval(7_200), duration: 30)])
        try await withFixture(response: response) { fixture in
            var preferences = fixture.library.preferences
            preferences.autoCalendar = true
            try fixture.library.savePreferences(preferences)
            fixture.system.writeError = .uncertainWrite(.calendar)
            let generated = try await fixture.controller.generate(goal: "Plan laundry", guide: nil)
            let action = try XCTUnwrap(generated.actions.first)
            XCTAssertEqual(action.status, .needsReview)
            XCTAssertNil(action.externalIdentifier)
            XCTAssertNotNil(action.error)
            XCTAssertNotNil(fixture.controller.issue)
            XCTAssertEqual(fixture.system.attempts.count, 1)
            let reopened = AdultAssistantLibrary(directory: fixture.directory)
            XCTAssertEqual(reopened.plans.first?.actions.first?.status, .needsReview)
            let bytes = try Data(contentsOf: fixture.archiveURL)
            fixture.system.writeError = nil
            let second = fixture.controllerFor(library: reopened)
            await second.apply(planID: generated.id, actionID: action.id)
            XCTAssertEqual(fixture.system.attempts.count, 1)
            XCTAssertEqual(try Data(contentsOf: fixture.archiveURL), bytes)
            XCTAssertNotNil(second.issue)
        }
    }

    @MainActor func testCanceledGenerationCannotPersistAPlanEvenWhenTheTransportReturnsValidData() async throws {
        let response = try providerResponse([draftAction(kind: "reminder", date: Date().addingTimeInterval(7_200))])
        try await withFixture(response: response, held: true) { fixture in
            var preferences = fixture.library.preferences
            preferences.autoReminders = true
            try fixture.library.savePreferences(preferences)
            let originalBytes = try Data(contentsOf: fixture.archiveURL)
            let task = Task { @MainActor in try await fixture.controller.generate(goal: "Plan laundry", guide: nil) }
            let entered = try await self.waitForRequest(fixture.transport)
            task.cancel()
            // The fake deliberately ignores cancellation while waiting, like an already-arriving response.
            await fixture.transport.release()
            do {
                _ = try await task.value
                XCTFail("Cancellation must be checked before adding the generated plan.")
            } catch is CancellationError {} catch { XCTFail("Expected cancellation, got \(error).") }
            XCTAssertTrue(entered, "The test must reach its held fake transport before cancelling.")
            XCTAssertTrue(fixture.library.plans.isEmpty)
            XCTAssertEqual(try Data(contentsOf: fixture.archiveURL), originalBytes)
            XCTAssertTrue(fixture.system.attempts.isEmpty)
            XCTAssertNil(fixture.controller.selectedPlanID)
            XCTAssertFalse(fixture.controller.isWorking)
        }
    }

    @MainActor func testRapidStartKeepsOneGenerationAndItsCancellationHandle() async throws {
        let response = try providerResponse([draftAction(kind: "reminder", date: Date().addingTimeInterval(7_200))])
        try await withFixture(response: response, held: true) { fixture in
            fixture.controller.goal = "Plan laundry"
            // Both calls occur synchronously before their main-actor task can begin.
            fixture.controller.startPlan()
            fixture.controller.startPlan()
            let entered = try await self.waitForRequest(fixture.transport)
            fixture.controller.cancelGeneration()
            await fixture.transport.release()
            let idle = try await self.waitForIdle(fixture.controller)
            let count = await fixture.transport.requestCount()
            XCTAssertTrue(entered)
            XCTAssertTrue(idle)
            XCTAssertEqual(count, 1)
            XCTAssertEqual(fixture.keys.readCount, 1)
            XCTAssertTrue(fixture.library.plans.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.archiveURL.path))
            XCTAssertTrue(fixture.system.attempts.isEmpty)
            XCTAssertNil(fixture.controller.issue)
        }
    }

    @MainActor func testDeniedAutomationPermissionDoesNotPersistOptInOrExecuteAPendingPlan() async throws {
        let response = try providerResponse([draftAction(kind: "reminder", date: Date().addingTimeInterval(7_200))])
        try await withFixture(response: response) { fixture in
            let original = self.oldPlan()
            try fixture.library.add(original)
            let before = try Data(contentsOf: fixture.archiveURL)
            fixture.system.notificationsAllowed = false
            await fixture.controller.setAutomation(.reminder, enabled: true)
            XCTAssertEqual(fixture.system.notificationPermissions, 1)
            XCTAssertFalse(fixture.library.preferences.autoReminders)
            XCTAssertEqual(try Data(contentsOf: fixture.archiveURL), before)
            XCTAssertEqual(fixture.library.plans, [original])
            XCTAssertNotNil(fixture.controller.issue)
            XCTAssertFalse(fixture.controller.isConfiguring)
            XCTAssertTrue(fixture.system.attempts.isEmpty)
            let count = await fixture.transport.requestCount()
            XCTAssertEqual(count, 0)
        }
    }
}

@MainActor private struct AdultControllerFixture {
    let directory: URL
    let suiteName: String
    let preferences: UserDefaults
    let previousPreferences: [String: Any]?
    let library: AdultAssistantLibrary
    let connection: AdultAIConnection
    let keys: AdultControllerKeys
    let transport: AdultControllerTransport
    let system: AdultControllerActionSystem
    let controller: AdultAssistantController
    var archiveURL: URL { directory.appendingPathComponent("AssistantLibrary-v1.json") }

    init(response: Data, held: Bool) throws {
        let id = UUID().uuidString
        guard UUID(uuidString: id) != nil else { throw FixtureError.invalidPrivateID }
        suiteName = "AdultAssistantControllerTests." + id
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("AdultAssistantControllerTests-" + id, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: directory.path), let preferences = UserDefaults(suiteName: suiteName) else {
            throw FixtureError.invalidPrivateID
        }
        self.preferences = preferences
        previousPreferences = preferences.persistentDomain(forName: suiteName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        preferences.set(AdultAIProvider.openAI.rawValue, forKey: "adult.ai.provider")
        preferences.set("offline-selected-model", forKey: "adult.ai.model")
        preferences.set(false, forKey: "adult.ai.research")
        library = AdultAssistantLibrary(directory: directory)
        keys = AdultControllerKeys()
        connection = AdultAIConnection(preferences: preferences, isPrivateQA: false, keys: keys)
        transport = AdultControllerTransport(response: response, held: held)
        system = AdultControllerActionSystem()
        controller = AdultAssistantController(library: library, connection: connection,
            service: AdultAIService(transport: transport), executor: AdultActionExecutor(system: system), isPrivateQA: false)
    }

    func controllerFor(library: AdultAssistantLibrary) -> AdultAssistantController {
        AdultAssistantController(library: library, connection: connection, service: AdultAIService(transport: transport),
                                 executor: AdultActionExecutor(system: system), isPrivateQA: false)
    }

    func cleanup() {
        system.beforeWrite = nil
        controller.cancelGeneration()
        let suffix = String(suiteName.dropFirst("AdultAssistantControllerTests.".count))
        guard suiteName.hasPrefix("AdultAssistantControllerTests."), UUID(uuidString: suffix) != nil,
              directory.lastPathComponent == "AdultAssistantControllerTests-" + suffix else { return }
        if let previousPreferences { preferences.setPersistentDomain(previousPreferences, forName: suiteName) }
        else { preferences.removePersistentDomain(forName: suiteName) }
        try? FileManager.default.removeItem(at: directory)
    }

    enum FixtureError: Error { case invalidPrivateID }
}

/// Only the MainActor-owned fixture connection calls this non-Sendable, in-memory key store.
private final class AdultControllerKeys: AdultAIKeyStorage {
    private var value: String? = "offline-fixture-not-an-api-key"
    private(set) var readCount = 0
    func containsKey() -> Bool { value != nil }
    func read() throws -> String {
        readCount += 1
        guard let value else { throw AdultAIConnectionError.noKey }
        return value
    }
    func save(_ value: String) throws { self.value = value }
    func remove() throws { value = nil }
}

private actor AdultControllerTransport: AdultAITransport {
    private let response: Data
    private var held: Bool
    private var continuation: CheckedContinuation<Data, Never>?
    private var requests: [URLRequest] = []
    init(response: Data, held: Bool) { self.response = response; self.held = held }
    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        guard requests.count == 1 else { throw FixtureError.unexpectedRequest }
        if held { return await withCheckedContinuation { continuation = $0 } }
        return response
    }
    func release() {
        held = false
        let waiting = continuation
        continuation = nil
        waiting?.resume(returning: response)
    }
    func requestCount() -> Int { requests.count }
    enum FixtureError: Error { case unexpectedRequest }
}

@MainActor private final class AdultControllerActionSystem: AdultActionSystem {
    struct Attempt {
        let service: AdultActionService
        let request: AdultNativeActionRequest
    }
    var beforeWrite: (@MainActor (AdultNativeActionRequest, AdultActionService) throws -> Void)?
    var writeError: AdultActionExecutionError?
    var notificationsAllowed = true
    private(set) var notificationPermissions = 0
    private(set) var calendarPermissions = 0
    private(set) var reminderPermissions = 0
    private(set) var attempts: [Attempt] = []
    func authorizeNotifications() async throws -> Bool { notificationPermissions += 1; return notificationsAllowed }
    func authorizeCalendar(calendarIdentifier: String?) async throws { calendarPermissions += 1 }
    func authorizeReminders(listIdentifier: String) async throws { reminderPermissions += 1 }
    func pendingNotificationIdentifiers() async -> [String] { [] }
    private func observe(_ request: AdultNativeActionRequest, service: AdultActionService) throws {
        try beforeWrite?(request, service)
        attempts.append(Attempt(service: service, request: request))
        if let writeError { throw writeError }
    }
    func scheduleNotification(_ request: AdultNativeActionRequest) async throws -> String {
        try observe(request, service: .notifications)
        return request.notificationIdentifier
    }
    func createCalendarEvent(_ request: AdultNativeActionRequest, calendarIdentifier: String?) async throws -> String {
        try observe(request, service: .calendar)
        return "fixture-calendar-" + request.id.uuidString
    }
    func exportReminder(_ request: AdultNativeActionRequest, listIdentifier: String) async throws -> String {
        try observe(request, service: .reminders)
        return "fixture-reminders-" + request.id.uuidString
    }
}
