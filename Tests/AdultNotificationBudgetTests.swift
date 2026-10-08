import XCTest
import UserNotifications
@testable import HowToAdult

final class AdultNotificationBudgetTests: XCTestCase {
    @MainActor private func request(_ identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Private budget test"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    @MainActor func testConcurrentWritersWithFiftyNinePendingCanAddOnlyOne() async {
        let system = FakeAdultNotificationScheduling(pending: Set((0..<59).map { "existing-\($0)" }))
        system.holdFirstRead = true
        system.holdFirstAdd = true
        defer { system.resumeRead(); system.resumeAdd() }
        let firstRequest = request("first-new")
        let secondRequest = request("second-new")
        let first = Task { @MainActor in try await AdultNotificationBudget.add(firstRequest, system: system) }
        await system.readStarted.wait()

        let secondStarted = NotificationTestCheckpoint()
        let second = Task { @MainActor in
            secondStarted.signal()
            try await AdultNotificationBudget.add(secondRequest, system: system)
        }
        await secondStarted.wait()
        await Task.yield()
        XCTAssertEqual(system.readCount, 1, "The second writer must wait before reading a stale snapshot.")
        XCTAssertEqual(system.addCount, 0)

        system.resumeRead()
        await system.addStarted.wait()
        XCTAssertEqual(system.readCount, 1, "The lock must also cover the suspended native add.")
        system.resumeAdd()

        if case .failure(let error) = await first.result { XCTFail("First write failed: \(error)") }
        switch await second.result {
        case .success: XCTFail("A second new request would exceed the shared budget.")
        case .failure(let error): XCTAssertEqual(error as? AdultActionExecutionError, .notificationLimit)
        }
        XCTAssertEqual(system.pending.count, 60)
        XCTAssertTrue(system.pending.contains("first-new"))
        XCTAssertFalse(system.pending.contains("second-new"))
        XCTAssertEqual(system.addCount, 1)
        XCTAssertEqual(system.readCount, 2)
    }

    @MainActor func testReplacementAtSixtyDoesNotConsumeAnotherSlot() async throws {
        let system = FakeAdultNotificationScheduling(pending: Set((0..<60).map { "existing-\($0)" }))
        try await AdultNotificationBudget.add(request("existing-12"), system: system)
        XCTAssertEqual(system.pending.count, 60)
        XCTAssertEqual(system.addedIdentifiers, ["existing-12"])
        XCTAssertEqual(system.readCount, 1)
    }

    @MainActor func testCancelledQueuedWriterDoesNotAddOrLeakTheLock() async throws {
        let system = FakeAdultNotificationScheduling(pending: [])
        system.holdFirstAdd = true
        defer { system.resumeRead(); system.resumeAdd() }
        let firstRequest = request("first")
        let cancelledRequest = request("cancelled")
        let first = Task { @MainActor in try await AdultNotificationBudget.add(firstRequest, system: system) }
        await system.addStarted.wait()

        let queuedStarted = NotificationTestCheckpoint()
        let queued = Task { @MainActor in
            queuedStarted.signal()
            try await AdultNotificationBudget.add(cancelledRequest, system: system)
        }
        await queuedStarted.wait()
        await Task.yield()
        XCTAssertEqual(system.readCount, 1)
        queued.cancel()
        system.resumeAdd()

        if case .failure(let error) = await first.result { XCTFail("First write failed: \(error)") }
        switch await queued.result {
        case .success: XCTFail("The cancelled queued request must not be written.")
        case .failure(let error): XCTAssertEqual(error as? AdultActionExecutionError, .cancelledBeforeWrite)
        }
        XCTAssertEqual(system.addedIdentifiers, ["first"])
        XCTAssertEqual(system.readCount, 1, "Cancellation is checked before the queued writer reads.")

        try await AdultNotificationBudget.add(request("after-cancellation"), system: system)
        XCTAssertEqual(system.addedIdentifiers, ["first", "after-cancellation"])
        XCTAssertEqual(system.pending, ["first", "after-cancellation"])
        XCTAssertEqual(system.readCount, 2)
    }
}

@MainActor
private final class NotificationTestCheckpoint {
    private var reached = false
    private var observers: [CheckedContinuation<Void, Never>] = []
    func signal() {
        reached = true
        let waiting = observers
        observers.removeAll()
        for observer in waiting { observer.resume() }
    }
    func wait() async {
        if reached { return }
        await withCheckedContinuation { observers.append($0) }
    }
}

@MainActor
private final class FakeAdultNotificationScheduling: AdultNotificationScheduling {
    var pending: Set<String>
    var holdFirstRead = false
    var holdFirstAdd = false
    private(set) var readCount = 0
    private(set) var addCount = 0
    private(set) var addedIdentifiers: [String] = []
    let readStarted = NotificationTestCheckpoint()
    let addStarted = NotificationTestCheckpoint()
    private var suspendedRead: CheckedContinuation<Void, Never>?
    private var suspendedAdd: CheckedContinuation<Void, Never>?

    init(pending: Set<String>) { self.pending = pending }
    func pendingIdentifiers() async -> [String] {
        readCount += 1
        let snapshot = Array(pending)
        if holdFirstRead {
            holdFirstRead = false
            await withCheckedContinuation { continuation in
                suspendedRead = continuation
                readStarted.signal()
            }
        }
        return snapshot
    }
    func add(_ request: UNNotificationRequest) async throws {
        addCount += 1
        if holdFirstAdd {
            holdFirstAdd = false
            await withCheckedContinuation { continuation in
                suspendedAdd = continuation
                addStarted.signal()
            }
        }
        pending.insert(request.identifier)
        addedIdentifiers.append(request.identifier)
    }
    func resumeRead() {
        let continuation = suspendedRead
        suspendedRead = nil
        continuation?.resume()
    }
    func resumeAdd() {
        let continuation = suspendedAdd
        suspendedAdd = nil
        continuation?.resume()
    }
}
