import UserNotifications

@MainActor protocol AdultNotificationScheduling {
    func pendingIdentifiers() async -> [String]
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor struct AdultNativeNotificationScheduling: AdultNotificationScheduling {
    func pendingIdentifiers() async -> [String] { await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier) }
    func add(_ request: UNNotificationRequest) async throws { try await UNUserNotificationCenter.current().add(request) }
}

/// Guide and assistant reminders share one serialized read/write budget.
@MainActor enum AdultNotificationBudget {
    private static var isWriting = false
    private static var waiting: [CheckedContinuation<Void, Never>] = []
    static func add(_ request: UNNotificationRequest, system: any AdultNotificationScheduling = AdultNativeNotificationScheduling()) async throws {
        await acquire()
        defer { release() }
        if Task.isCancelled { throw AdultActionExecutionError.cancelledBeforeWrite }
        let pending = Set(await system.pendingIdentifiers())
        if Task.isCancelled { throw AdultActionExecutionError.cancelledBeforeWrite }
        guard pending.contains(request.identifier) || pending.count < 60 else { throw AdultActionExecutionError.notificationLimit }
        try await system.add(request)
    }

    private static func acquire() async {
        if !isWriting { isWriting = true; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    private static func release() {
        if waiting.isEmpty { isWriting = false }
        else { waiting.removeFirst().resume() }
    }
}
