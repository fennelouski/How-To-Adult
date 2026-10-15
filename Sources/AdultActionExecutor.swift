import Foundation
import UserNotifications
import EventKit

enum AdultActionService: String, Sendable {
    case notifications, calendar, reminders
}

enum AdultActionExecutionError: LocalizedError, Equatable {
    case invalidAction, notPrepared, alreadyCompleted, needsReview, busy, unsupportedAction
    case automationDisabled, scheduleInPast, missingDuration, recurrenceStart
    case permissionDenied(AdultActionService), permissionRequestFailed(AdultActionService)
    case notificationLimit, selectedCalendarNeedsFullAccess, destinationUnavailable(AdultActionService)
    case cancelledBeforeWrite, uncertainWrite(AdultActionService), missingReceipt(AdultActionService)

    /// Only a known pre-write failure may be retried without reviewing the external service.
    var uncertainOutcome: Bool {
        switch self {
        case .uncertainWrite, .missingReceipt: true
        default: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidAction: "Check this action’s title, date and details before trying again."
        case .notPrepared: "Save this action’s execution state before scheduling it."
        case .alreadyCompleted: "This action already has a completed receipt."
        case .needsReview: "Check the existing reminder or event before trying this action again."
        case .busy: "Another action is being scheduled. Try again when it finishes."
        case .unsupportedAction: "This action is prepared in the plan; it does not create a calendar item or reminder."
        case .automationDisabled: "Enable this action’s automation in Settings before scheduling it."
        case .scheduleInPast: "Choose a date and time in the future."
        case .missingDuration: "Choose a calendar duration between 5 minutes and 24 hours."
        case .recurrenceStart: "Repeating app reminders start at the next matching time. Choose that next occurrence, or use a one-time reminder."
        case .permissionDenied(.notifications): "Allow How to Adult notifications in system Settings to schedule this reminder."
        case .permissionDenied(.calendar): "Allow calendar access in system Settings to add this event."
        case .permissionDenied(.reminders): "Allow Reminders access in system Settings to add this task."
        case .permissionRequestFailed: "Permission could not be checked. No action was written; try again."
        case .notificationLimit: "There are already 60 pending app reminders. Remove one before adding another."
        case .selectedCalendarNeedsFullAccess: "Selecting a calendar requires full calendar access. Use the system default calendar with write-only access."
        case .destinationUnavailable(.calendar): "The chosen calendar is unavailable or does not allow new events."
        case .destinationUnavailable(.reminders): "The chosen Reminders list is unavailable or does not allow new tasks."
        case .destinationUnavailable(.notifications): "The notification service is unavailable."
        case .cancelledBeforeWrite: "Scheduling was cancelled before any action was written."
        case .uncertainWrite(.calendar), .missingReceipt(.calendar): "The calendar save may have completed. Check Calendar before trying again."
        case .uncertainWrite(.reminders), .missingReceipt(.reminders): "The reminder save may have completed. Check Reminders before trying again."
        case .uncertainWrite(.notifications), .missingReceipt(.notifications): "The reminder may have been scheduled. Review this action before trying again."
        }
    }
}

/// Value-only requests keep tests independent of EventKit and notification permissions.
struct AdultNativeActionRequest: Equatable, Sendable {
    let id: UUID
    let title: String
    let details: String
    let scheduledAt: Date
    let durationMinutes: Int?
    let repeatRule: AdultActionRepeat
    let sound: Bool

    var notificationIdentifier: String { "AdultAssistant." + id.uuidString }
    var ownedNotes: String { details + "\n\nHow to Adult action: " + id.uuidString }

    /// Recurrence is local-calendar time. Monthly dates absent from a month are skipped.
    func triggerComponents(calendar: Calendar) -> DateComponents {
        let fields: Set<Calendar.Component>
        switch repeatRule {
        case .none: fields = [.year, .month, .day, .hour, .minute, .second]
        case .daily: fields = [.hour, .minute, .second]
        case .weekly: fields = [.weekday, .hour, .minute, .second]
        case .monthly: fields = [.day, .hour, .minute, .second]
        }
        var components = calendar.dateComponents(fields, from: scheduledAt)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
    }

    func nextRecurringDate(after date: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: date, matching: triggerComponents(calendar: calendar),
                          matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward)
    }
}

@MainActor
protocol AdultActionSystem {
    func authorizeNotifications() async throws -> Bool
    func authorizeCalendar(calendarIdentifier: String?) async throws
    func authorizeReminders(listIdentifier: String) async throws
    func pendingNotificationIdentifiers() async -> [String]
    func scheduleNotification(_ request: AdultNativeActionRequest) async throws -> String
    func createCalendarEvent(_ request: AdultNativeActionRequest, calendarIdentifier: String?) async throws -> String
    func exportReminder(_ request: AdultNativeActionRequest, listIdentifier: String) async throws -> String
}

@MainActor
final class AdultActionExecutor {
    private let system: any AdultActionSystem
    private let now: () -> Date
    private var isExecuting = false

    init(system: any AdultActionSystem = AdultNativeActionSystem(), now: @escaping () -> Date = Date.init) {
        self.system = system
        self.now = now
    }

    /// Settings calls this before saving an opt-in. It never creates an item.
    func requestPermission(for kind: AdultActionKind, preferences: AdultAutomationPreferences) async throws {
        do { try preferences.validate() }
        catch { throw AdultActionExecutionError.invalidAction }
        guard !isExecuting else { throw AdultActionExecutionError.busy }
        isExecuting = true
        defer { isExecuting = false }
        try checkCancellation()
        switch kind {
        case .reminder:
            if let list = preferences.reminderListIdentifier {
                do { try await system.authorizeReminders(listIdentifier: list) }
                catch let error as AdultActionExecutionError { throw error }
                catch { throw AdultActionExecutionError.permissionRequestFailed(.reminders) }
            } else {
                let granted: Bool
                do { granted = try await system.authorizeNotifications() }
                catch let error as AdultActionExecutionError { throw error }
                catch { throw AdultActionExecutionError.permissionRequestFailed(.notifications) }
                guard granted else { throw AdultActionExecutionError.permissionDenied(.notifications) }
            }
        case .calendar:
            do { try await system.authorizeCalendar(calendarIdentifier: preferences.calendarIdentifier) }
            catch let error as AdultActionExecutionError { throw error }
            catch { throw AdultActionExecutionError.permissionRequestFailed(.calendar) }
        default: throw AdultActionExecutionError.unsupportedAction
        }
        try checkCancellation()
    }

    /// The caller first persists `.running` with AdultAssistantLibrary.beginExecution.
    /// A returned identifier is a real system receipt, never a generated completion claim.
    func execute(action: AdultAssistantAction, preferences: AdultAutomationPreferences) async throws -> String {
        if action.status == .completed { throw AdultActionExecutionError.alreadyCompleted }
        if action.status == .needsReview || action.externalIdentifier != nil { throw AdultActionExecutionError.needsReview }
        guard action.status == .running else { throw AdultActionExecutionError.notPrepared }
        guard action.kind == .reminder || action.kind == .calendar else { throw AdultActionExecutionError.unsupportedAction }
        do { try action.validate(); try preferences.validate() }
        catch { throw AdultActionExecutionError.invalidAction }
        guard let date = action.scheduledAt, date > now() else { throw AdultActionExecutionError.scheduleInPast }
        guard action.kind == .reminder ? preferences.autoReminders : preferences.autoCalendar else {
            throw AdultActionExecutionError.automationDisabled
        }
        if action.kind == .calendar {
            guard let duration = action.durationMinutes, (5...1_440).contains(duration) else {
                throw AdultActionExecutionError.missingDuration
            }
        }
        guard !isExecuting else { throw AdultActionExecutionError.busy }
        isExecuting = true
        defer { isExecuting = false }
        try checkCancellation()
        let request = AdultNativeActionRequest(id: action.id, title: action.title, details: action.details,
            scheduledAt: date, durationMinutes: action.durationMinutes, repeatRule: action.repeatRule, sound: preferences.sound)

        if action.kind == .calendar {
            return try await externalWrite(service: .calendar) {
                try await self.system.createCalendarEvent(request, calendarIdentifier: preferences.calendarIdentifier)
            }
        }
        if let list = preferences.reminderListIdentifier {
            return try await externalWrite(service: .reminders) {
                try await self.system.exportReminder(request, listIdentifier: list)
            }
        }
        try validateRecurringStart(request)
        let authorized: Bool
        do { authorized = try await system.authorizeNotifications() }
        catch let error as AdultActionExecutionError { throw error }
        catch { throw AdultActionExecutionError.permissionRequestFailed(.notifications) }
        guard authorized else { throw AdultActionExecutionError.permissionDenied(.notifications) }
        let pending = Set(await system.pendingNotificationIdentifiers())
        guard pending.contains(request.notificationIdentifier) || pending.count < 60 else {
            throw AdultActionExecutionError.notificationLimit
        }
        try checkCancellation()
        guard date > now() else { throw AdultActionExecutionError.scheduleInPast }
        try validateRecurringStart(request)
        return try await externalWrite(service: .notifications) {
            let identifier = try await self.system.scheduleNotification(request)
            guard identifier == request.notificationIdentifier else {
                throw AdultActionExecutionError.missingReceipt(.notifications)
            }
            return identifier
        }
    }

    private func validateRecurringStart(_ request: AdultNativeActionRequest) throws {
        guard request.repeatRule != .none else { return }
        // A repeating UN trigger has no distant start boundary. Never schedule it early.
        guard let next = request.nextRecurringDate(after: now(), calendar: .current),
              abs(next.timeIntervalSince(request.scheduledAt)) < 1 else {
            throw AdultActionExecutionError.recurrenceStart
        }
    }

    private func checkCancellation() throws {
        if Task.isCancelled { throw AdultActionExecutionError.cancelledBeforeWrite }
    }

    private func externalWrite(service: AdultActionService, operation: () async throws -> String) async throws -> String {
        do {
            let identifier = try await operation()
            guard AdultAssistantValidation.text(identifier, maximum: 512) else {
                throw AdultActionExecutionError.missingReceipt(service)
            }
            return identifier
        } catch let error as AdultActionExecutionError { throw error }
        catch { throw AdultActionExecutionError.uncertainWrite(service) }
    }
}

/// Construction has no effects. EventKit is lazy until an explicit permission or execution request.
@MainActor
final class AdultNativeActionSystem: AdultActionSystem {
    private var eventStore: EKEventStore?
    private func storeForExecution() -> EKEventStore {
        if let eventStore { return eventStore }
        let store = EKEventStore()
        eventStore = store
        return store
    }

    func authorizeNotifications() async throws -> Bool {
        do { return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        catch { throw AdultActionExecutionError.permissionRequestFailed(.notifications) }
    }

    func pendingNotificationIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func authorizeCalendar(calendarIdentifier: String?) async throws {
        _ = try await calendarForNewEvent(identifier: calendarIdentifier)
    }

    func authorizeReminders(listIdentifier: String) async throws {
        _ = try await listForNewReminder(identifier: listIdentifier)
    }

    func scheduleNotification(_ request: AdultNativeActionRequest) async throws -> String {
        if Task.isCancelled { throw AdultActionExecutionError.cancelledBeforeWrite }
        guard request.scheduledAt > Date() else { throw AdultActionExecutionError.scheduleInPast }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.details.isEmpty ? "Your next step is ready." : request.details
        content.userInfo = ["assistantActionID": request.id.uuidString]
        if request.sound { content.sound = .default }
        let trigger = UNCalendarNotificationTrigger(dateMatching: request.triggerComponents(calendar: .current),
            repeats: request.repeatRule != .none)
        do {
            try await AdultNotificationBudget.add(UNNotificationRequest(
                identifier: request.notificationIdentifier, content: content, trigger: trigger))
        } catch let error as AdultActionExecutionError { throw error }
        catch { throw AdultActionExecutionError.uncertainWrite(.notifications) }
        return request.notificationIdentifier
    }

    func createCalendarEvent(_ request: AdultNativeActionRequest, calendarIdentifier: String?) async throws -> String {
        let calendar = try await calendarForNewEvent(identifier: calendarIdentifier)
        guard let duration = request.durationMinutes, (5...1_440).contains(duration) else {
            throw AdultActionExecutionError.missingDuration
        }
        if Task.isCancelled { throw AdultActionExecutionError.cancelledBeforeWrite }
        guard request.scheduledAt > Date() else { throw AdultActionExecutionError.scheduleInPast }
        let store = storeForExecution()
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = request.title
        event.notes = request.ownedNotes
        event.startDate = request.scheduledAt
        event.endDate = request.scheduledAt.addingTimeInterval(TimeInterval(duration * 60))
        event.timeZone = .current
        if let recurrence = recurrenceRule(request.repeatRule) { event.addRecurrenceRule(recurrence) }
        do { try store.save(event, span: .thisEvent, commit: true) }
        catch { throw AdultActionExecutionError.uncertainWrite(.calendar) }
        // Write-only access cannot verify a later lookup. Persist this receipt; interrupted saves need review.
        guard let identifier = event.eventIdentifier, !identifier.isEmpty else {
            throw AdultActionExecutionError.missingReceipt(.calendar)
        }
        return identifier
    }

    private func calendarForNewEvent(identifier: String?) async throws -> EKCalendar {
        let store = storeForExecution()
        var access = EKEventStore.authorizationStatus(for: .event)
        if access == .notDetermined {
            do {
                guard try await store.requestWriteOnlyAccessToEvents() else {
                    throw AdultActionExecutionError.permissionDenied(.calendar)
                }
            } catch let error as AdultActionExecutionError { throw error }
            catch { throw AdultActionExecutionError.permissionRequestFailed(.calendar) }
            access = EKEventStore.authorizationStatus(for: .event)
        }
        guard access == .writeOnly || access == .fullAccess else {
            throw AdultActionExecutionError.permissionDenied(.calendar)
        }
        let calendar: EKCalendar?
        if let identifier {
            guard access == .fullAccess else { throw AdultActionExecutionError.selectedCalendarNeedsFullAccess }
            calendar = store.calendar(withIdentifier: identifier)
        } else { calendar = store.defaultCalendarForNewEvents }
        guard let calendar, calendar.allowsContentModifications, calendar.allowedEntityTypes.contains(.event) else {
            throw AdultActionExecutionError.destinationUnavailable(.calendar)
        }
        return calendar
    }

    func exportReminder(_ request: AdultNativeActionRequest, listIdentifier: String) async throws -> String {
        let calendar = try await listForNewReminder(identifier: listIdentifier)
        if Task.isCancelled { throw AdultActionExecutionError.cancelledBeforeWrite }
        guard request.scheduledAt > Date() else { throw AdultActionExecutionError.scheduleInPast }
        let store = storeForExecution()
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = request.title
        reminder.notes = request.ownedNotes
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .timeZone], from: request.scheduledAt)
        reminder.addAlarm(EKAlarm(absoluteDate: request.scheduledAt))
        if let recurrence = recurrenceRule(request.repeatRule) { reminder.addRecurrenceRule(recurrence) }
        do { try store.save(reminder, commit: true) }
        catch { throw AdultActionExecutionError.uncertainWrite(.reminders) }
        guard !reminder.calendarItemIdentifier.isEmpty else { throw AdultActionExecutionError.missingReceipt(.reminders) }
        return reminder.calendarItemIdentifier
    }

    private func listForNewReminder(identifier: String) async throws -> EKCalendar {
        let store = storeForExecution()
        var access = EKEventStore.authorizationStatus(for: .reminder)
        if access == .notDetermined {
            do {
                guard try await store.requestFullAccessToReminders() else {
                    throw AdultActionExecutionError.permissionDenied(.reminders)
                }
            } catch let error as AdultActionExecutionError { throw error }
            catch { throw AdultActionExecutionError.permissionRequestFailed(.reminders) }
            access = EKEventStore.authorizationStatus(for: .reminder)
        }
        guard access == .fullAccess else { throw AdultActionExecutionError.permissionDenied(.reminders) }
        guard let calendar = store.calendar(withIdentifier: identifier), calendar.allowsContentModifications,
              calendar.allowedEntityTypes.contains(.reminder) else {
            throw AdultActionExecutionError.destinationUnavailable(.reminders)
        }
        return calendar
    }

    private func recurrenceRule(_ rule: AdultActionRepeat) -> EKRecurrenceRule? {
        let frequency: EKRecurrenceFrequency
        switch rule {
        case .none: return nil
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil)
    }
}
