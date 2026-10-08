import AppIntents

struct MakeAdultPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Make a life plan"
    static let description = IntentDescription("Turn an everyday task into a saved plan using the AI you connected in How to Adult. Applies reminders and calendar events only if enabled in the app.")
    static let openAppWhenRun = false

    @Parameter(title: "Task", description: "What would you like to get done?")
    var task: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["ADULT_QA_BLANK_HOST"] != "1",
              !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--adult-private-qa") })
        else { throw AdultAIConnectionError.unavailable }
        #endif
        let assistant = AdultAssistantRuntime.shared
        let plan = try await assistant.generate(goal: task, guide: nil)
        let count = plan.actions.filter { $0.status == .completed }.count
        return .result(dialog: "Saved \(plan.title). \(count) actions applied; open How to Adult to review the rest.")
    }
}

struct AdultAssistantShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MakeAdultPlanIntent(), phrases: ["Make a life plan in \(.applicationName)"], shortTitle: "Make a life plan", systemImageName: "sparkles")
    }
}
