import Foundation
import Observation

@MainActor @Observable
final class AdultAssistantController {
    let library: AdultAssistantLibrary
    let connection: AdultAIConnection
    let isPrivateQA: Bool
    let privateSessionID: UUID?
    var goal = ""
    var guide: AdultArticle?
    var selectedPlanID: UUID?
    var requestedPresentationID: UUID?
    var issue: String?
    private(set) var isWorking = false
    private(set) var busyActionID: UUID?
    private(set) var isConfiguring = false
    @ObservationIgnored private let service: AdultAIService
    @ObservationIgnored private let executor: AdultActionExecutor
    @ObservationIgnored private var generation: Task<Void, Never>?

    init(library: AdultAssistantLibrary = AdultAssistantLibrary(),
         connection: AdultAIConnection = AdultAIConnection(), service: AdultAIService = AdultAIService(),
         executor: AdultActionExecutor = AdultActionExecutor(), isPrivateQA: Bool = false, privateSessionID: UUID? = nil) {
        self.library = library
        self.connection = connection
        self.service = service
        self.executor = executor
        self.isPrivateQA = isPrivateQA
        self.privateSessionID = privateSessionID
    }

    var selectedPlan: AdultAssistantPlan? { library.plans.first { $0.id == selectedPlanID } }

    func prepare(_ article: AdultArticle) {
        guide = article
        goal = "Help me \(article.title.lowercased())."
        selectedPlanID = nil
        requestedPresentationID = UUID()
    }

    func startPlan() {
        guard !isWorking, generation == nil else { return }
        let goal = goal
        let guide = guide
        generation = Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.generate(goal: goal, guide: guide) }
            catch is CancellationError { }
            catch { self.issue = Self.message(error) }
            self.generation = nil
        }
    }

    func cancelGeneration() { generation?.cancel() }

    @discardableResult func generate(goal: String, guide: AdultArticle?) async throws -> AdultAssistantPlan {
        guard !isWorking, busyActionID == nil, !isConfiguring else { throw AdultActionExecutionError.busy }
        guard library.canSave else { throw AdultAssistantError.storageUnavailable }
        guard !isPrivateQA else { throw AdultAIConnectionError.unavailable }
        if connection.provider == .onDevice && !AdultAIService.onDeviceAvailable { throw AdultAIConnectionError.unavailable }
        isWorking = true
        defer { isWorking = false }
        let provider = connection.provider
        let key = provider == .openAI ? try connection.apiKey() : nil
        let plan = try await service.makePlan(goal: goal, guide: guide, provider: provider,
            model: connection.model, key: key, research: provider == .openAI && connection.useWebResearch)
        try Task.checkCancellation()
        try library.add(plan)
        selectedPlanID = plan.id
        requestedPresentationID = UUID()
        // Opt-in applies only to this newly created plan. Existing plans are never replayed.
        for action in plan.actions {
            if Task.isCancelled { break }
            let enabled = action.kind == .reminder ? library.preferences.autoReminders :
                action.kind == .calendar && library.preferences.autoCalendar
            if enabled, let date = action.scheduledAt, date > Date(),
               action.kind != .calendar || action.durationMinutes != nil {
                await apply(planID: plan.id, actionID: action.id)
            }
        }
        return library.plans.first { $0.id == plan.id } ?? plan
    }

    func apply(planID: UUID, actionID: UUID) async {
        guard busyActionID == nil, !isPrivateQA else { return }
        busyActionID = actionID
        defer { busyActionID = nil }
        var began = false
        var receivedReceipt = false
        do {
            let action = try library.beginExecution(planID: planID, actionID: actionID)
            began = true
            var preferences = library.preferences
            // A tap on a reviewed action authorizes this write without enabling future automation.
            if action.kind == .calendar { preferences.autoCalendar = true }
            if action.kind == .reminder { preferences.autoReminders = true }
            let receipt = try await executor.execute(action: action, preferences: preferences)
            receivedReceipt = true
            try library.finishExecution(planID: planID, actionID: actionID, externalIdentifier: receipt)
        } catch {
            let uncertain = receivedReceipt || (error as? AdultActionExecutionError)?.uncertainOutcome == true || error is CancellationError
            let message = receivedReceipt ? "The item was created, but its receipt could not be saved. Check Calendar or your reminders before another attempt." : Self.message(error)
            if began { _ = try? library.failExecution(planID: planID, actionID: actionID, error: message, needsReview: uncertain) }
            issue = message
        }
    }

    func complete(planID: UUID, action: AdultAssistantAction) {
        do {
            let completion: AdultLocalActionCompletion
            switch action.kind {
            case .shopping: completion = .shoppingListPrepared
            case .checklist: completion = .checklistChecked
            default: throw AdultAssistantError.unsupportedLocalCompletion
            }
            try library.completeLocalAction(planID: planID, actionID: action.id, completion: completion)
        } catch { issue = Self.message(error) }
    }

    func research(planID: UUID, action: AdultAssistantAction) async {
        guard busyActionID == nil, !isPrivateQA else { return }
        busyActionID = action.id
        defer { busyActionID = nil }
        do {
            let current = try library.action(planID: planID, actionID: action.id)
            guard current.status == .pending || current.status == .failed else { throw AdultAssistantError.invalidTransition }
            guard let query = current.query else { throw AdultAssistantError.invalidAction }
            let result = try await service.research(goal: query, model: connection.model, key: connection.apiKey())
            try Task.checkCancellation()
            try library.completeResearchAction(planID: planID, actionID: action.id,
                evidence: AdultResearchEvidence(text: result.text, citations: result.citations, checkedAt: Date()))
        } catch is CancellationError { }
        catch { issue = Self.message(error) }
    }

    func researchShopping(planID: UUID, action: AdultAssistantAction) async {
        guard busyActionID == nil, !isPrivateQA else { return }
        busyActionID = action.id
        defer { busyActionID = nil }
        do {
            let current = try library.action(planID: planID, actionID: action.id)
            guard current.kind == .shopping, current.status == .pending || current.status == .failed else { throw AdultAssistantError.invalidTransition }
            let query = "Find shopping options using original retailer sources. Do not guess location, prices, inventory, or purchase anything. Explain what must be checked at checkout.\n" +
                (current.query ?? current.title) + "\nItems: " + current.items.joined(separator: ", ")
            let result = try await service.research(goal: query, model: connection.model, key: connection.apiKey())
            try Task.checkCancellation()
            try library.saveActionResearch(planID: planID, actionID: action.id,
                evidence: AdultResearchEvidence(text: result.text, citations: result.citations, checkedAt: Date()))
        } catch is CancellationError { }
        catch { issue = Self.message(error) }
    }

    func deletePlan(_ id: UUID) {
        do { try library.remove(planID: id); if selectedPlanID == id { selectedPlanID = nil } }
        catch { issue = Self.message(error) }
    }

    func setAutomation(_ kind: AdultActionKind, enabled: Bool) async {
        guard !isPrivateQA, busyActionID == nil, !isWorking, !isConfiguring else { return }
        isConfiguring = true
        defer { isConfiguring = false }
        do {
            var preferences = library.preferences
            if enabled { try await executor.requestPermission(for: kind, preferences: preferences) }
            if kind == .reminder { preferences.autoReminders = enabled }
            if kind == .calendar { preferences.autoCalendar = enabled }
            try library.savePreferences(preferences)
        } catch { issue = Self.message(error) }
    }

    func testConnection() async throws {
        guard !isPrivateQA, !isWorking, !isConfiguring, busyActionID == nil else { throw AdultActionExecutionError.busy }
        isConfiguring = true
        defer { isConfiguring = false }
        try await service.testConnection(model: connection.model, key: connection.apiKey())
    }

    static func message(_ error: Error) -> String {
        if let error = error as? AdultAIConnectionError { return error.localizedDescription }
        if let error = error as? AdultAssistantError { return error.localizedDescription }
        if let error = error as? AdultActionExecutionError { return error.localizedDescription }
        return "This action could not be completed. Your saved plans are preserved. Try again."
    }
}

/// A single in-process owner is shared by windows and Shortcuts to avoid lost updates.
@MainActor enum AdultAssistantRuntime {
    static let shared = AdultAssistantController()
}
