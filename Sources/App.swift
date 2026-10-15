import SwiftUI

@main
struct HowToAdultApp: App {
    @State private var store: AdultStore?
    @State private var assistant: AdultAssistantController?
    @State private var privatePreferences: UserDefaults?
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
                let session = try? AdultPassportReviewSession(id: id)
                _passportReview = State(initialValue: session)
                _privatePreferences = State(initialValue: session?.preferences)
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
            _privatePreferences = State(initialValue: preferences)
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
            _store = State(initialValue: AdultStore(directory: directory, allowsRemoteUpdates: false, allowsNotifications: false, allowsArtworkReads: ProcessInfo.processInfo.arguments.contains("--qa-library")))
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
            .defaultAppStorage(privatePreferences ?? .standard)
            #if DEBUG
            .modifier(AdultQAAppearance())
            #endif
            #if os(macOS)
            .frame(minWidth: 390, minHeight: 520)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 820)
        #endif
    }

    @ViewBuilder private var ordinaryRoot: some View {
        if let store, let assistant {
            AdultAppearanceRoot().environment(store).environment(assistant)
        } else { Color.clear.accessibilityIdentifier("adult-blank-test-host") }
    }
}

private struct AdultAppearanceRoot: View {
    @AppStorage("adultAppearance") private var appearance = "system"
    var body: some View {
        AdultRootView().preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
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
