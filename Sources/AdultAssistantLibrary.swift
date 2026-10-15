import Foundation
import Observation

@MainActor @Observable
final class AdultAssistantLibrary {
    private(set) var plans: [AdultAssistantPlan] = []
    private(set) var preferences = AdultAutomationPreferences()
    private(set) var storageIssue: String?
    private(set) var canSave = false

    @ObservationIgnored private let directory: URL
    private var file: URL { directory.appendingPathComponent("AssistantLibrary-v1.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HowToAdult", isDirectory: true)
        reload()
    }

    /// Never repairs a corrupt file by replacing it with an empty library.
    func reload() {
        canSave = false
        do {
            guard directory.isFileURL else { throw AdultAssistantError.storageUnavailable }
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                throw AdultAssistantError.storageUnavailable
            }
            var archive = AdultAssistantArchive()
            if FileManager.default.fileExists(atPath: file.path) {
                let handle = try FileHandle(forReadingFrom: file)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: AdultAssistantValidation.maximumBytes + 1) ?? Data()
                archive = try AdultAssistantArchive.decode(data)
            }
            var recovered = archive
            var interrupted = false
            for planIndex in recovered.plans.indices {
                for actionIndex in recovered.plans[planIndex].actions.indices {
                    if recovered.plans[planIndex].actions[actionIndex].status == .running {
                        recovered.plans[planIndex].actions[actionIndex].status = .needsReview
                        recovered.plans[planIndex].actions[actionIndex].error = "The previous attempt was interrupted. Check for an existing reminder or event before trying again."
                        recovered.plans[planIndex].actions[actionIndex].updatedAt = Date()
                        interrupted = true
                    }
                }
            }
            if interrupted { try write(recovered) }
            plans = recovered.plans
            preferences = recovered.preferences
            canSave = true
            storageIssue = nil
        } catch {
            storageIssue = "Your saved plans could not be opened safely. The original file is preserved. Check available storage, then retry."
        }
    }

    @discardableResult func add(_ plan: AdultAssistantPlan) throws -> AdultAssistantPlan {
        // Generated drafts cannot smuggle execution receipts into the library.
        guard plan.actions.allSatisfy({ $0.status == .pending && $0.externalIdentifier == nil && $0.localCompletion == nil })
        else { throw AdultAssistantError.invalidTransition }
        var next = archive
        next.plans.insert(plan, at: 0)
        try commit(next)
        return plan
    }

    func savePreferences(_ preferences: AdultAutomationPreferences) throws {
        var next = archive
        next.preferences = preferences
        try commit(next)
    }

    /// Removes the local plan only. Previously created native items are left intact.
    /// The UI must confirm loss of review receipts before removing a needs-review plan.
    func remove(planID: UUID) throws {
        var next = archive
        guard let index = next.plans.firstIndex(where: { $0.id == planID }) else { throw AdultAssistantError.planNotFound }
        guard next.plans[index].actions.allSatisfy({ $0.status != .running }) else { throw AdultAssistantError.executionInProgress }
        next.plans.remove(at: index)
        try commit(next)
    }

    @discardableResult func updateDraftAction(planID: UUID, action: AdultAssistantAction) throws -> AdultAssistantAction {
        try change(planID: planID, actionID: action.id) { current in
            guard current.status == .pending || current.status == .failed,
                  action.status == .pending || action.status == .failed,
                  action.externalIdentifier == nil, action.localCompletion == nil else { throw AdultAssistantError.invalidTransition }
            current = action
            current.status = .pending
            current.error = nil
            current.updatedAt = Date()
        }
    }

    /// Returning this snapshot authorizes one attempt only after `.running` is on disk.
    @discardableResult func beginExecution(planID: UUID, actionID: UUID) throws -> AdultAssistantAction {
        try change(planID: planID, actionID: actionID) { action in
            guard action.kind == .reminder || action.kind == .calendar,
                  action.status == .pending || action.status == .failed,
                  action.externalIdentifier == nil else { throw AdultAssistantError.invalidTransition }
            guard let date = action.scheduledAt else { throw AdultAssistantError.missingSchedule }
            guard date > Date() else { throw AdultAssistantError.scheduleInPast }
            if action.kind == .calendar && action.durationMinutes == nil { throw AdultAssistantError.missingDuration }
            action.status = .running
            action.error = nil
            action.updatedAt = Date()
        }
    }

    @discardableResult func finishExecution(planID: UUID, actionID: UUID, externalIdentifier: String) throws -> AdultAssistantAction {
        guard AdultAssistantValidation.text(externalIdentifier, maximum: 512) else { throw AdultAssistantError.missingExternalIdentifier }
        let existing = try action(planID: planID, actionID: actionID)
        if existing.status == .completed && existing.externalIdentifier == externalIdentifier { return existing }
        return try change(planID: planID, actionID: actionID) { action in
            guard action.status == .running, action.kind == .reminder || action.kind == .calendar else { throw AdultAssistantError.invalidTransition }
            action.status = .completed
            action.externalIdentifier = externalIdentifier
            action.error = nil
            action.updatedAt = Date()
        }
    }

    /// `needsReview: false` means the executor knows that no external write occurred.
    /// A timeout, cancellation or unknown service outcome must use `true`.
    @discardableResult func failExecution(planID: UUID, actionID: UUID, error: String, needsReview: Bool) throws -> AdultAssistantAction {
        guard AdultAssistantValidation.text(error, maximum: 2_000) else { throw AdultAssistantError.invalidAction }
        return try change(planID: planID, actionID: actionID) { action in
            guard action.status == .running else { throw AdultAssistantError.invalidTransition }
            action.status = needsReview ? .needsReview : .failed
            action.error = error
            action.updatedAt = Date()
        }
    }

    @discardableResult func reviewExecution(planID: UUID, actionID: UUID, resolution: AdultExecutionReview) throws -> AdultAssistantAction {
        try change(planID: planID, actionID: actionID) { action in
            guard action.status == .needsReview, action.kind == .reminder || action.kind == .calendar else { throw AdultAssistantError.invalidTransition }
            switch resolution {
            case .confirmedExisting(let identifier):
                guard AdultAssistantValidation.text(identifier, maximum: 512) else { throw AdultAssistantError.missingExternalIdentifier }
                action.status = .completed
                action.externalIdentifier = identifier
            case .confirmedNoEffect:
                action.status = .pending
                action.externalIdentifier = nil
            }
            action.error = nil
            action.updatedAt = Date()
        }
    }

    @discardableResult func completeLocalAction(planID: UUID, actionID: UUID, completion: AdultLocalActionCompletion) throws -> AdultAssistantAction {
        let existing = try action(planID: planID, actionID: actionID)
        guard existing.kind == completion.kind else { throw AdultAssistantError.unsupportedLocalCompletion }
        if existing.status == .completed && existing.localCompletion == completion { return existing }
        return try change(planID: planID, actionID: actionID) { action in
            guard action.status == .pending || action.status == .failed else { throw AdultAssistantError.invalidTransition }
            action.status = .completed
            action.localCompletion = completion
            action.externalIdentifier = nil
            action.error = nil
            action.updatedAt = Date()
        }
    }

    func saveResearchEvidence(planID: UUID, evidence: AdultResearchEvidence) throws {
        var next = archive
        guard let planIndex = next.plans.firstIndex(where: { $0.id == planID }) else { throw AdultAssistantError.planNotFound }
        next.plans[planIndex].researchEvidence = evidence
        appendCitations(evidence.citations, to: &next.plans[planIndex])
        try commit(next)
    }

    /// Read-only research does not complete shopping, purchase anything, or start a native write.
    func saveActionResearch(planID: UUID, actionID: UUID, evidence: AdultResearchEvidence) throws {
        var next = archive
        guard let planIndex = next.plans.firstIndex(where: { $0.id == planID }),
              let actionIndex = next.plans[planIndex].actions.firstIndex(where: { $0.id == actionID })
        else { throw AdultAssistantError.actionNotFound }
        let action = next.plans[planIndex].actions[actionIndex]
        guard action.kind == .shopping || action.kind == .research else { throw AdultAssistantError.unsupportedLocalCompletion }
        guard action.status == .pending || action.status == .failed else { throw AdultAssistantError.invalidTransition }
        next.plans[planIndex].actions[actionIndex].researchEvidence = evidence
        next.plans[planIndex].actions[actionIndex].updatedAt = Date()
        appendCitations(evidence.citations, to: &next.plans[planIndex])
        try commit(next)
    }

    /// Keep the original sourced answer and the local completion receipt in one atomic write.
    @discardableResult func completeResearchAction(planID: UUID, actionID: UUID, evidence: AdultResearchEvidence) throws -> AdultAssistantAction {
        var next = archive
        guard let planIndex = next.plans.firstIndex(where: { $0.id == planID }),
              let actionIndex = next.plans[planIndex].actions.firstIndex(where: { $0.id == actionID })
        else { throw AdultAssistantError.actionNotFound }
        var action = next.plans[planIndex].actions[actionIndex]
        guard action.kind == .research else { throw AdultAssistantError.unsupportedLocalCompletion }
        if action.status == .completed && action.localCompletion == .researchOpened && action.researchEvidence == evidence { return action }
        guard action.status == .pending || action.status == .failed else { throw AdultAssistantError.invalidTransition }
        action.status = .completed
        action.localCompletion = .researchOpened
        action.externalIdentifier = nil
        action.error = nil
        action.updatedAt = Date()
        action.researchEvidence = evidence
        next.plans[planIndex].actions[actionIndex] = action
        appendCitations(evidence.citations, to: &next.plans[planIndex])
        try commit(next)
        return action
    }

    private func appendCitations(_ citations: [AdultAssistantCitation], to plan: inout AdultAssistantPlan) {
        for citation in citations where !plan.citations.contains(where: { $0.url == citation.url }) {
            plan.citations.append(citation)
        }
    }

    func action(planID: UUID, actionID: UUID) throws -> AdultAssistantAction {
        guard let action = plans.first(where: { $0.id == planID })?.actions.first(where: { $0.id == actionID })
        else { throw AdultAssistantError.actionNotFound }
        return action
    }

    private var archive: AdultAssistantArchive { AdultAssistantArchive(plans: plans, preferences: preferences) }

    private func change(planID: UUID, actionID: UUID, edit: (inout AdultAssistantAction) throws -> Void) throws -> AdultAssistantAction {
        var next = archive
        guard let planIndex = next.plans.firstIndex(where: { $0.id == planID }),
              let actionIndex = next.plans[planIndex].actions.firstIndex(where: { $0.id == actionID })
        else { throw AdultAssistantError.actionNotFound }
        try edit(&next.plans[planIndex].actions[actionIndex])
        try commit(next)
        return next.plans[planIndex].actions[actionIndex]
    }

    private func commit(_ next: AdultAssistantArchive) throws {
        guard canSave else { throw AdultAssistantError.storageUnavailable }
        do {
            try write(next)
        } catch let error as AdultAssistantError where error != .writeFailed {
            throw error
        } catch {
            storageIssue = AdultAssistantError.writeFailed.localizedDescription
            throw AdultAssistantError.writeFailed
        }
        plans = next.plans
        preferences = next.preferences
        storageIssue = nil
    }

    private func write(_ next: AdultAssistantArchive) throws {
        try next.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(next)
        guard data.count <= AdultAssistantValidation.maximumBytes else { throw AdultAssistantError.tooLarge }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }
}
