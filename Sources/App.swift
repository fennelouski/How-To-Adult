import SwiftUI

@main
struct HowToAdultApp: App {
    @State private var store: AdultStore?
    @State private var assistant: AdultAssistantController?
    #if DEBUG
    @State private var passportReview: AdultPassportReviewSession?
    #endif

    init() {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--adult-passport-review") }) {
            _store = State(initialValue: nil)
            _assistant = State(initialValue: nil)
            if argument.hasPrefix("--adult-passport-review="),
               let id = UUID(uuidString: String(argument.dropFirst("--adult-passport-review=".count))) {
                _passportReview = State(initialValue: try? AdultPassportReviewSession(id: id))
            }
            return
        }
        // Test hosts must branch before touching the normal library, preferences or Keychain.
        let privateArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--adult-private-qa") })
        if ProcessInfo.processInfo.environment["ADULT_QA_BLANK_HOST"] == "1" && privateArgument == nil {
            _store = State(initialValue: nil)
            _assistant = State(initialValue: nil)
            return
        }
        if let privateArgument {
            guard privateArgument.hasPrefix("--adult-private-qa="),
                  let id = UUID(uuidString: String(privateArgument.dropFirst("--adult-private-qa=".count))) else {
                _store = State(initialValue: nil)
                _assistant = State(initialValue: nil)
                return
            }
            let directory = URL.applicationSupportDirectory.appendingPathComponent("HowToAdult-PrivateQA/" + id.uuidString, isDirectory: true)
            let library = AdultAssistantLibrary(directory: directory)
            let preferences = UserDefaults(suiteName: "com.nathanfennel.How-To-Adult.PrivateQA." + id.uuidString)!
            let preview = AdultAssistantController(library: library,
                connection: AdultAIConnection(preferences: preferences, isPrivateQA: true), isPrivateQA: true, privateSessionID: id)
            let fixture = AdultAssistantPlan(title: "A calmer Sunday", summary: "Three small steps to make next week feel lighter.",
                goal: "Plan a Sunday reset", provider: .onDevice, actions: [
                    AdultAssistantAction(kind: .calendar, title: "Make room for a weekly reset", details: "A quiet half hour to plan meals and tidy one room.", scheduledAt: Date().addingTimeInterval(86_400), durationMinutes: 30),
                    AdultAssistantAction(kind: .reminder, title: "Move the laundry to the dryer", details: "Check the care label before choosing a heat setting.", scheduledAt: Date().addingTimeInterval(3_600)),
                    AdultAssistantAction(kind: .shopping, title: "Keep dinner simple", items: ["Chickpeas", "Rice", "A vegetable you enjoy"], query: "chickpeas rice vegetables"),
                    AdultAssistantAction(kind: .checklist, title: "Give tomorrow a head start", items: ["Clear one surface", "Set out tomorrow’s clothes"])
                ])
            if library.plans.isEmpty { _ = try? library.add(fixture) }
            if ProcessInfo.processInfo.arguments.contains("--qa-plan") { preview.selectedPlanID = library.plans.first?.id }
            _store = State(initialValue: AdultStore(directory: directory, allowsRemoteUpdates: false, allowsNotifications: false))
            _assistant = State(initialValue: preview)
            return
        }
        #endif
        let store = AdultStore()
        store.installNotificationRouting()
        _store = State(initialValue: store)
        _assistant = State(initialValue: AdultAssistantRuntime.shared)
    }

    var body: some Scene {
        WindowGroup(id: "library") {
            Group {
                #if DEBUG
                if let passportReview {
                    AdultPassportReviewRoot()
                        .environment(passportReview.guides).environment(passportReview.assistant).environment(passportReview.passport)
                } else { ordinaryRoot }
                #else
                ordinaryRoot
                #endif
            }
                #if DEBUG
                .modifier(AdultQAAppearance())
                #endif
                #if os(macOS) || os(visionOS)
                .frame(minWidth: 680, minHeight: 520)
                #endif
        }
        #if os(macOS) || os(visionOS)
        .defaultSize(width: 1180, height: 820)
        #endif
        #if os(visionOS)
        .windowResizability(.contentMinSize)
        #endif

        #if os(visionOS)
        WindowGroup("Guide", id: "guide", for: String.self) { $guideID in
            if let store, let assistant, let guideID {
                GuideWindowView(guideID: guideID)
                    .environment(store).environment(assistant)
                    .frame(minWidth: 480, maxWidth: 900, minHeight: 420, maxHeight: 1100)
            }
        }
        .defaultSize(width: 620, height: 760)
        .windowResizability(.contentSize)
        .defaultWindowPlacement { _, context in
            guard let library = context.windows.first(where: { $0.id == "library" }) else { return WindowPlacement(nil) }
            return WindowPlacement(.trailing(library))
        }

        WindowGroup("Assistant", id: "assistant") {
            if let store, let assistant {
                NavigationStack { AdultAssistantView() }
                    .environment(store).environment(assistant)
                    .frame(minWidth: 540, minHeight: 520)
            }
        }
        .defaultSize(width: 720, height: 760)
        .windowResizability(.contentMinSize)
        .defaultWindowPlacement { _, context in
            guard let library = context.windows.first(where: { $0.id == "library" }) else { return WindowPlacement(nil) }
            return WindowPlacement(.leading(library))
        }
        #endif
    }

    @ViewBuilder private var ordinaryRoot: some View {
        if let store, let assistant {
            AdultRootView().environment(store).environment(assistant)
        } else { Color.clear.accessibilityIdentifier("adult-blank-test-host") }
    }
}

#if DEBUG
private struct AdultQAAppearance: ViewModifier {
    @Environment(\.dynamicTypeSize) private var inheritedTypeSize

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--qa-dark") ? .dark : nil)
            .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--qa-accessibility-text") ? .accessibility3 : inheritedTypeSize)
    }
}
#endif
