import XCTest
@testable import HowToAdult

final class AdultActionExecutorTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private func action(kind: AdultActionKind = .reminder, status: AdultActionStatus = .running) -> AdultAssistantAction {
        AdultAssistantAction(kind: kind, title: "Laundry", details: "Check the care label.",
            scheduledAt: fixedNow.addingTimeInterval(3_600), durationMinutes: kind == .calendar ? 30 : nil,
            status: status, updatedAt: fixedNow)
    }

    private func enabledPreferences() -> AdultAutomationPreferences {
        var preferences = AdultAutomationPreferences()
        preferences.autoReminders = true
        preferences.autoCalendar = true
        return preferences
    }

    @MainActor private func expect(_ expected: AdultActionExecutionError, operation: () async throws -> Void) async {
        do { try await operation(); XCTFail("Expected \(expected)") }
        catch { XCTAssertEqual(error as? AdultActionExecutionError, expected) }
    }

    @MainActor func testPermissionOptInDoesNotCreateAnItem() async throws {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        let preferences = AdultAutomationPreferences()
        try await executor.requestPermission(for: .reminder, preferences: preferences)
        try await executor.requestPermission(for: .calendar, preferences: preferences)
        var reminders = preferences
        reminders.reminderListIdentifier = "chosen-list"
        try await executor.requestPermission(for: .reminder, preferences: reminders)
        XCTAssertEqual(system.notificationAuthorizations, 1)
        XCTAssertEqual(system.calendarAuthorizations, [nil])
        XCTAssertEqual(system.reminderAuthorizations, ["chosen-list"])
        XCTAssertEqual(system.writeCount, 0)
        XCTAssertEqual(system.pendingReads, 0)
    }

    @MainActor func testDeniedPermissionAndPermissionFailureHaveNoWriteOutcome() async {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        system.notificationsAllowed = false
        await expect(.permissionDenied(.notifications)) {
            try await executor.requestPermission(for: .reminder, preferences: AdultAutomationPreferences())
        }
        system.authorizationError = MockFailure.service
        await expect(.permissionRequestFailed(.calendar)) {
            try await executor.requestPermission(for: .calendar, preferences: AdultAutomationPreferences())
        }
        XCTAssertEqual(system.writeCount, 0)
        XCTAssertFalse(AdultActionExecutionError.permissionDenied(.notifications).uncertainOutcome)
        XCTAssertFalse(AdultActionExecutionError.permissionRequestFailed(.calendar).uncertainOutcome)
    }

    @MainActor func testOnlyDurablyRunningActionsCanExecute() async {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        for status in [AdultActionStatus.pending, .failed] {
            await expect(.notPrepared) {
                _ = try await executor.execute(action: self.action(status: status), preferences: self.enabledPreferences())
            }
        }
        await expect(.alreadyCompleted) {
            _ = try await executor.execute(action: self.action(status: .completed), preferences: self.enabledPreferences())
        }
        await expect(.needsReview) {
            _ = try await executor.execute(action: self.action(status: .needsReview), preferences: self.enabledPreferences())
        }
        var receipt = action()
        receipt.externalIdentifier = "existing-native-item"
        await expect(.needsReview) {
            _ = try await executor.execute(action: receipt, preferences: self.enabledPreferences())
        }
        XCTAssertEqual(system.writeCount, 0)
        XCTAssertEqual(system.notificationAuthorizations, 0)
    }

    @MainActor func testDisabledAutomationAndInvalidScheduleDoNotAskPermission() async {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        await expect(.automationDisabled) {
            _ = try await executor.execute(action: self.action(), preferences: AdultAutomationPreferences())
        }
        for date in [Optional<Date>.none, fixedNow, fixedNow.addingTimeInterval(-1)] {
            var invalid = action()
            invalid.scheduledAt = date
            await expect(.scheduleInPast) {
                _ = try await executor.execute(action: invalid, preferences: self.enabledPreferences())
            }
        }
        var calendar = action(kind: .calendar)
        calendar.durationMinutes = nil
        await expect(.missingDuration) {
            _ = try await executor.execute(action: calendar, preferences: self.enabledPreferences())
        }
        XCTAssertEqual(system.writeCount, 0)
        XCTAssertEqual(system.notificationAuthorizations, 0)
    }

    @MainActor func testRunningReminderReturnsItsStableNativeIdentifier() async throws {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        let original = action()
        var preferences = enabledPreferences()
        preferences.sound = false
        let receipt = try await executor.execute(action: original, preferences: preferences)
        XCTAssertEqual(receipt, "AdultAssistant." + original.id.uuidString)
        XCTAssertEqual(system.notificationRequests.first?.id, original.id)
        XCTAssertEqual(system.notificationRequests.first?.sound, false)
        XCTAssertEqual(system.notificationRequests.first?.details, original.details)
        XCTAssertEqual(system.calendarRequests.count, 0)
        XCTAssertEqual(system.reminderRequests.count, 0)
    }

    @MainActor func testAllPendingNotificationsShareTheSixtyRequestBudget() async {
        let system = MockAdultActionSystem()
        system.pending = (0..<40).map { "AdultGuide.guide-\($0)" } + (0..<20).map { "AdultAssistant.other-\($0)" }
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        await expect(.notificationLimit) {
            _ = try await executor.execute(action: self.action(), preferences: self.enabledPreferences())
        }
        XCTAssertEqual(system.notificationRequests.count, 0)
        XCTAssertEqual(system.pending.count, 60)
    }

    @MainActor func testAnExistingStableNotificationCanBeReplacedAtTheBudget() async throws {
        let system = MockAdultActionSystem()
        let original = action()
        let identifier = "AdultAssistant." + original.id.uuidString
        system.pending = [identifier] + (0..<59).map { "other-\($0)" }
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        let first = try await executor.execute(action: original, preferences: enabledPreferences())
        let second = try await executor.execute(action: original, preferences: enabledPreferences())
        XCTAssertEqual(first, identifier)
        XCTAssertEqual(second, identifier)
        XCTAssertEqual(Set(system.pending).count, 60)
        XCTAssertEqual(Set(system.notificationRequests.map(\.notificationIdentifier)), [identifier])
    }

    @MainActor func testDistantRecurringNotificationCannotFireBeforeItsPlannedStart() async {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        var distant = action()
        distant.repeatRule = .daily
        distant.scheduledAt = Calendar.current.date(byAdding: .day, value: 2, to: distant.scheduledAt!)
        await expect(.recurrenceStart) {
            _ = try await executor.execute(action: distant, preferences: self.enabledPreferences())
        }
        XCTAssertEqual(system.notificationAuthorizations, 0)
        XCTAssertEqual(system.writeCount, 0)
    }

    @MainActor func testNextDailyOccurrenceCanBeScheduled() async throws {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        var recurring = action()
        recurring.repeatRule = .daily
        let receipt = try await executor.execute(action: recurring, preferences: enabledPreferences())
        XCTAssertEqual(receipt, "AdultAssistant." + recurring.id.uuidString)
        XCTAssertEqual(system.notificationRequests.first?.repeatRule, .daily)
    }

    func testCalendarRecurrenceComponentsPreserveLocalTimeAndSkipMissingMonthDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9, minute: 15)))
        func request(_ rule: AdultActionRepeat) -> AdultNativeActionRequest {
            AdultNativeActionRequest(id: UUID(), title: "Monthly task", details: "", scheduledAt: date,
                durationMinutes: nil, repeatRule: rule, sound: true)
        }
        let daily = request(.daily).triggerComponents(calendar: calendar)
        XCTAssertNil(daily.day)
        XCTAssertNil(daily.year)
        XCTAssertEqual(daily.hour, 9)
        XCTAssertEqual(daily.minute, 15)
        XCTAssertEqual(daily.timeZone, calendar.timeZone)
        let weekly = request(.weekly).triggerComponents(calendar: calendar)
        XCTAssertEqual(weekly.weekday, calendar.component(.weekday, from: date))
        XCTAssertNil(weekly.day)
        let monthly = request(.monthly).triggerComponents(calendar: calendar)
        XCTAssertEqual(monthly.day, 31)
        XCTAssertNil(monthly.month)
        let after = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 2, day: 1)))
        let next = try XCTUnwrap(request(.monthly).nextRecurringDate(after: after, calendar: calendar))
        XCTAssertEqual(calendar.component(.year, from: next), 2027)
        XCTAssertEqual(calendar.component(.month, from: next), 3)
        XCTAssertEqual(calendar.component(.day, from: next), 31)
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
        XCTAssertEqual(calendar.component(.minute, from: next), 15)
        let oneTime = request(.none).triggerComponents(calendar: calendar)
        XCTAssertEqual(oneTime.year, 2027)
        XCTAssertEqual(oneTime.month, 1)
        XCTAssertEqual(oneTime.day, 31)
    }

    @MainActor func testCalendarAndChosenRemindersListReturnActualReceipts() async throws {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        var preferences = enabledPreferences()
        preferences.calendarIdentifier = "chosen-calendar"
        preferences.reminderListIdentifier = "chosen-list"
        var event = action(kind: .calendar)
        event.repeatRule = .weekly
        let calendarID = try await executor.execute(action: event, preferences: preferences)
        let reminderID = try await executor.execute(action: action(), preferences: preferences)
        XCTAssertEqual(calendarID, "native-event-id")
        XCTAssertEqual(reminderID, "native-reminder-id")
        XCTAssertEqual(system.calendarDestinations, ["chosen-calendar"])
        XCTAssertEqual(system.reminderDestinations, ["chosen-list"])
        XCTAssertEqual(system.calendarRequests.first?.durationMinutes, 30)
        XCTAssertEqual(system.calendarRequests.first?.repeatRule, .weekly)
        XCTAssertEqual(system.notificationAuthorizations, 0)
        XCTAssertEqual(system.notificationRequests.count, 0)
    }

    @MainActor func testUnknownWriteAndMissingReceiptRequireReview() async {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        system.writeError = MockFailure.service
        await expect(.uncertainWrite(.calendar)) {
            _ = try await executor.execute(action: self.action(kind: .calendar), preferences: self.enabledPreferences())
        }
        system.writeError = nil
        system.calendarReceipt = " "
        await expect(.missingReceipt(.calendar)) {
            _ = try await executor.execute(action: self.action(kind: .calendar), preferences: self.enabledPreferences())
        }
        system.notificationReceipt = "invented-notification-id"
        await expect(.missingReceipt(.notifications)) {
            _ = try await executor.execute(action: self.action(), preferences: self.enabledPreferences())
        }
        XCTAssertTrue(AdultActionExecutionError.uncertainWrite(.calendar).uncertainOutcome)
        XCTAssertTrue(AdultActionExecutionError.missingReceipt(.notifications).uncertainOutcome)
    }

    @MainActor func testKnownCalendarPermissionFailureRemainsSafeToRetry() async {
        let system = MockAdultActionSystem()
        system.writeError = AdultActionExecutionError.permissionDenied(.calendar)
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        await expect(.permissionDenied(.calendar)) {
            _ = try await executor.execute(action: self.action(kind: .calendar), preferences: self.enabledPreferences())
        }
        XCTAssertFalse(AdultActionExecutionError.permissionDenied(.calendar).uncertainOutcome)
    }

    @MainActor func testDateIsCheckedAgainAfterPermissionWait() async {
        let system = MockAdultActionSystem()
        var clock = fixedNow
        let original = action()
        system.afterAuthorization = { clock = original.scheduledAt!.addingTimeInterval(1) }
        let executor = AdultActionExecutor(system: system, now: { clock })
        await expect(.scheduleInPast) {
            _ = try await executor.execute(action: original, preferences: self.enabledPreferences())
        }
        XCTAssertEqual(system.writeCount, 0)
    }

    @MainActor func testCancellationBeforeExecutionCreatesNoItem() async {
        let system = MockAdultActionSystem()
        let executor = AdultActionExecutor(system: system, now: { self.fixedNow })
        let original = action()
        let preferences = enabledPreferences()
        let operation = Task { @MainActor in
            try await executor.execute(action: original, preferences: preferences)
        }
        operation.cancel()
        switch await operation.result {
        case .success: XCTFail("A cancelled execution must not create an item.")
        case .failure(let error): XCTAssertEqual(error as? AdultActionExecutionError, .cancelledBeforeWrite)
        }
        XCTAssertEqual(system.notificationAuthorizations, 0)
        XCTAssertEqual(system.writeCount, 0)
    }
}

private enum MockFailure: Error { case service }

@MainActor
private final class MockAdultActionSystem: AdultActionSystem {
    var notificationsAllowed = true
    var authorizationError: (any Error)?
    var writeError: (any Error)?
    var pending: [String] = []
    var notificationReceipt: String?
    var calendarReceipt = "native-event-id"
    var reminderReceipt = "native-reminder-id"
    var afterAuthorization: (() -> Void)?
    var notificationAuthorizations = 0
    var calendarAuthorizations: [String?] = []
    var reminderAuthorizations: [String] = []
    var pendingReads = 0
    var notificationRequests: [AdultNativeActionRequest] = []
    var calendarRequests: [AdultNativeActionRequest] = []
    var reminderRequests: [AdultNativeActionRequest] = []
    var calendarDestinations: [String?] = []
    var reminderDestinations: [String] = []
    var writeCount: Int { notificationRequests.count + calendarRequests.count + reminderRequests.count }

    func authorizeNotifications() async throws -> Bool {
        notificationAuthorizations += 1
        if let authorizationError { throw authorizationError }
        afterAuthorization?()
        return notificationsAllowed
    }
    func authorizeCalendar(calendarIdentifier: String?) async throws {
        calendarAuthorizations.append(calendarIdentifier)
        if let authorizationError { throw authorizationError }
    }
    func authorizeReminders(listIdentifier: String) async throws {
        reminderAuthorizations.append(listIdentifier)
        if let authorizationError { throw authorizationError }
    }
    func pendingNotificationIdentifiers() async -> [String] {
        pendingReads += 1
        return pending
    }
    func scheduleNotification(_ request: AdultNativeActionRequest) async throws -> String {
        if let writeError { throw writeError }
        notificationRequests.append(request)
        if !pending.contains(request.notificationIdentifier) { pending.append(request.notificationIdentifier) }
        return notificationReceipt ?? request.notificationIdentifier
    }
    func createCalendarEvent(_ request: AdultNativeActionRequest, calendarIdentifier: String?) async throws -> String {
        if let writeError { throw writeError }
        calendarRequests.append(request)
        calendarDestinations.append(calendarIdentifier)
        return calendarReceipt
    }
    func exportReminder(_ request: AdultNativeActionRequest, listIdentifier: String) async throws -> String {
        if let writeError { throw writeError }
        reminderRequests.append(request)
        reminderDestinations.append(listIdentifier)
        return reminderReceipt
    }
}
