import Foundation

enum AdultAIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case onDevice, openAI
    var id: Self { self }
    var displayName: String { self == .onDevice ? "On device" : "OpenAI" }
}

enum AdultActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case reminder, calendar, research, shopping, checklist
    var id: Self { self }
}

enum AdultActionRepeat: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, daily, weekly, monthly
    var id: Self { self }
}

enum AdultActionStatus: String, Codable, Sendable {
    case pending, running, completed, failed, needsReview
}

/// Completion of local preparation does not represent a purchase or a native calendar write.
enum AdultLocalActionCompletion: String, Codable, Sendable {
    case checklistChecked, researchOpened, shoppingListPrepared

    var kind: AdultActionKind {
        switch self {
        case .checklistChecked: .checklist
        case .researchOpened: .research
        case .shoppingListPrepared: .shopping
        }
    }
}

enum AdultExecutionReview: Sendable {
    /// The user or executor has verified this existing native object.
    case confirmedExisting(externalIdentifier: String)
    /// The user has checked that the interrupted attempt created no native object.
    case confirmedNoEffect
}

struct AdultAssistantAction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var kind: AdultActionKind
    var title: String
    var details: String
    var scheduledAt: Date?
    var durationMinutes: Int?
    var repeatRule: AdultActionRepeat
    var items: [String]
    var query: String?
    var status: AdultActionStatus
    var externalIdentifier: String?
    var error: String?
    var updatedAt: Date
    var localCompletion: AdultLocalActionCompletion?
    var researchEvidence: AdultResearchEvidence?

    init(id: UUID = UUID(), kind: AdultActionKind, title: String, details: String = "",
         scheduledAt: Date? = nil, durationMinutes: Int? = nil,
         repeatRule: AdultActionRepeat = .none, items: [String] = [], query: String? = nil,
         status: AdultActionStatus = .pending, externalIdentifier: String? = nil,
         error: String? = nil, updatedAt: Date = Date(), localCompletion: AdultLocalActionCompletion? = nil,
         researchEvidence: AdultResearchEvidence? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.details = details
        self.scheduledAt = scheduledAt
        self.durationMinutes = durationMinutes
        self.repeatRule = repeatRule
        self.items = items
        self.query = query
        self.status = status
        self.externalIdentifier = externalIdentifier
        self.error = error
        self.updatedAt = updatedAt
        self.localCompletion = localCompletion
        self.researchEvidence = researchEvidence
    }

    func validate() throws {
        guard AdultAssistantValidation.text(title, maximum: 180),
              details.count <= 8_000, items.count <= 100,
              items.allSatisfy({ AdultAssistantValidation.text($0, maximum: 500) }),
              AdultAssistantValidation.date(updatedAt),
              scheduledAt.map(AdultAssistantValidation.date) ?? true,
              query.map({ AdultAssistantValidation.text($0, maximum: 2_000) }) ?? true,
              error.map({ AdultAssistantValidation.text($0, maximum: 2_000) }) ?? true,
              externalIdentifier.map({ AdultAssistantValidation.text($0, maximum: 512) }) ?? true
        else { throw AdultAssistantError.invalidAction }
        if let durationMinutes {
            let lowerBound = kind == .calendar ? 5 : 1
            guard (lowerBound...1_440).contains(durationMinutes) else { throw AdultAssistantError.invalidAction }
        }
        if kind != .calendar && kind != .reminder {
            guard repeatRule == .none, externalIdentifier == nil,
                  status != .running && status != .needsReview else { throw AdultAssistantError.invalidAction }
        }
        if kind == .research && query == nil { throw AdultAssistantError.invalidAction }
        if (kind == .shopping || kind == .checklist) && items.isEmpty { throw AdultAssistantError.invalidAction }
        if let researchEvidence {
            guard kind == .research || kind == .shopping else { throw AdultAssistantError.invalidResearchEvidence }
            try researchEvidence.validate()
        }

        switch status {
        case .pending, .running:
            guard externalIdentifier == nil, error == nil, localCompletion == nil else { throw AdultAssistantError.invalidAction }
        case .failed:
            guard externalIdentifier == nil, error != nil, localCompletion == nil else { throw AdultAssistantError.invalidAction }
        case .needsReview:
            guard error != nil, localCompletion == nil else { throw AdultAssistantError.invalidAction }
        case .completed:
            guard error == nil else { throw AdultAssistantError.invalidAction }
            if kind == .reminder || kind == .calendar {
                guard externalIdentifier != nil, localCompletion == nil else { throw AdultAssistantError.invalidAction }
            } else {
                guard localCompletion?.kind == kind else { throw AdultAssistantError.invalidAction }
            }
        }
        if let localCompletion, localCompletion.kind != kind { throw AdultAssistantError.invalidAction }
        if localCompletion == .researchOpened && researchEvidence == nil { throw AdultAssistantError.invalidResearchEvidence }
    }
}

enum AdultCitationSource: String, Codable, Sendable {
    case guide, webAnnotation
}

/// Provenance must come from a verified guide source or an actual provider web annotation.
/// A URL appearing in generated prose is not a citation.
struct AdultAssistantCitation: Codable, Equatable, Hashable, Sendable {
    let title: String
    let url: URL
    let source: AdultCitationSource
    let guideID: String?

    init(title: String, url: URL, source: AdultCitationSource, guideID: String? = nil) {
        self.title = title
        self.url = url
        self.source = source
        self.guideID = guideID
    }

    func validate() throws {
        guard AdultAssistantValidation.text(title, maximum: 240),
              url.absoluteString.count <= 2_048,
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil else { throw AdultAssistantError.invalidCitation }
        switch source {
        case .guide:
            guard let guideID, AdultAssistantValidation.guideID(guideID) else { throw AdultAssistantError.invalidCitation }
        case .webAnnotation:
            guard guideID == nil else { throw AdultAssistantError.invalidCitation }
        }
    }
}

struct AdultResearchEvidence: Codable, Equatable, Sendable {
    var text: String
    var citations: [AdultAssistantCitation]
    var checkedAt: Date

    func validate() throws {
        guard AdultAssistantValidation.text(text, maximum: 32_000),
              (1...50).contains(citations.count), AdultAssistantValidation.date(checkedAt)
        else { throw AdultAssistantError.invalidResearchEvidence }
        for citation in citations { try citation.validate() }
    }
}

struct AdultAssistantPlan: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var summary: String
    var goal: String
    var provider: AdultAIProvider
    let createdAt: Date
    var sourceGuideID: String?
    var actions: [AdultAssistantAction]
    var citations: [AdultAssistantCitation]
    var researchEvidence: AdultResearchEvidence?

    init(id: UUID = UUID(), title: String, summary: String, goal: String,
         provider: AdultAIProvider, createdAt: Date = Date(), sourceGuideID: String? = nil,
         actions: [AdultAssistantAction], citations: [AdultAssistantCitation] = [],
         researchEvidence: AdultResearchEvidence? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.goal = goal
        self.provider = provider
        self.createdAt = createdAt
        self.sourceGuideID = sourceGuideID
        self.actions = actions
        self.citations = citations
        self.researchEvidence = researchEvidence
    }

    func validate() throws {
        guard AdultAssistantValidation.text(title, maximum: 180),
              AdultAssistantValidation.text(summary, maximum: 2_000),
              AdultAssistantValidation.text(goal, maximum: 6_000),
              AdultAssistantValidation.date(createdAt),
              sourceGuideID.map(AdultAssistantValidation.guideID) ?? true,
              (1...AdultAssistantValidation.maximumActions).contains(actions.count),
              citations.count <= AdultAssistantValidation.maximumPlanCitations else { throw AdultAssistantError.invalidPlan }
        guard Set(actions.map(\.id)).count == actions.count else { throw AdultAssistantError.duplicateIdentifier }
        for action in actions { try action.validate() }
        for citation in citations { try citation.validate() }
        try researchEvidence?.validate()
    }
}

struct AdultAutomationPreferences: Codable, Equatable, Sendable {
    var autoReminders = false
    var autoCalendar = false
    var sound = true
    var calendarIdentifier: String?
    var reminderListIdentifier: String?

    func validate() throws {
        guard calendarIdentifier.map({ AdultAssistantValidation.text($0, maximum: 512) }) ?? true,
              reminderListIdentifier.map({ AdultAssistantValidation.text($0, maximum: 512) }) ?? true
        else { throw AdultAssistantError.invalidPreferences }
    }
}

enum AdultAssistantValidation {
    static let maximumPlans = 100
    static let maximumActions = 12
    static let maximumPlanCitations = 650
    static let maximumBytes = 2 * 1_024 * 1_024

    static func text(_ value: String, maximum: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= maximum && !value.contains("\u{0}")
    }

    static func guideID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 100 && value.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil
    }

    static func date(_ value: Date) -> Bool {
        let seconds = value.timeIntervalSince1970
        return seconds.isFinite && (-2_208_988_800...7_258_118_400).contains(seconds)
    }
}

enum AdultAssistantError: LocalizedError, Equatable {
    case invalidPlan, invalidAction, invalidCitation, invalidResearchEvidence, invalidPreferences, duplicateIdentifier
    case unsupportedVersion, tooLarge, storageUnavailable, writeFailed, actionNotFound, planNotFound, executionInProgress, invalidTransition
    case missingSchedule, scheduleInPast, missingDuration, missingExternalIdentifier, unsupportedLocalCompletion

    var errorDescription: String? {
        switch self {
        case .invalidPlan: "This plan is incomplete or exceeds the plan limits."
        case .invalidAction: "This action is incomplete or contains invalid details."
        case .invalidCitation: "This source needs a verified, secure web address."
        case .invalidResearchEvidence: "Save the original answer and its verified sources before completing this research."
        case .invalidPreferences: "Choose a valid calendar or reminder list."
        case .duplicateIdentifier: "This plan or action is already in your library."
        case .unsupportedVersion: "This plan library uses a format this app cannot open."
        case .tooLarge: "Your plan library exceeds the storage limit."
        case .storageUnavailable: "Your saved plans cannot be changed until their storage is available."
        case .writeFailed: "This change could not be saved. Your previous plans are preserved."
        case .actionNotFound: "This action is no longer in your plan library."
        case .planNotFound: "This plan is no longer in your library."
        case .executionInProgress: "Wait for the plan’s current action to finish before removing it."
        case .invalidTransition: "This action needs review before another attempt."
        case .missingSchedule: "Choose a date and time before scheduling this action."
        case .scheduleInPast: "Choose a date and time in the future."
        case .missingDuration: "Choose the event duration before adding it to your calendar."
        case .missingExternalIdentifier: "The action needs a receipt from the reminder or calendar service."
        case .unsupportedLocalCompletion: "This action needs its matching completion step."
        }
    }
}

struct AdultAssistantArchive: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var plans: [AdultAssistantPlan] = []
    var preferences = AdultAutomationPreferences()

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= AdultAssistantValidation.maximumBytes else { throw AdultAssistantError.tooLarge }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        try archive.validate()
        return archive
    }

    func validate() throws {
        guard schemaVersion == 1 else { throw AdultAssistantError.unsupportedVersion }
        guard plans.count <= AdultAssistantValidation.maximumPlans else { throw AdultAssistantError.invalidPlan }
        guard Set(plans.map(\.id)).count == plans.count else { throw AdultAssistantError.duplicateIdentifier }
        let actionIDs = plans.flatMap { $0.actions.map(\.id) }
        guard Set(actionIDs).count == actionIDs.count else { throw AdultAssistantError.duplicateIdentifier }
        for plan in plans { try plan.validate() }
        try preferences.validate()
    }
}
