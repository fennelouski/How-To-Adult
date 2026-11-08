import SwiftUI

struct AdultRootView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var section: AdultSection = .now
    @State private var paths: [AdultSection: [AdultRoute]] = [:]
    @State private var exploreFilter = GuideFilter()
    @State private var activeSheet: AdultSheet?

    private var usesSidebar: Bool {
        #if os(macOS) || os(visionOS)
        true
        #else
        sizeClass != .compact
        #endif
    }

    var body: some View {
        Group {
            if usesSidebar {
                // Assistant keeps its original three columns; the guide sections use sidebar + detail.
                if section == .assistant {
                    NavigationSplitView { sidebar } content: {
                        AdultPlanSidebar().navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 520)
                    } detail: { NavigationStack { AdultAssistantView() } }
                } else {
                    NavigationSplitView { sidebar } detail: { stack(for: section) }
                }
            } else {
                TabView(selection: $section) {
                    ForEach(AdultSection.allCases) { item in
                        Group {
                            if item == .assistant { NavigationStack { AdultAssistantView() } }
                            else { stack(for: item) }
                        }
                        .tabItem { Label(item.rawValue, systemImage: item.symbol) }
                        .tag(item)
                    }
                }
            }
        }
        .tint(AdultPalette.accent)
        #if os(visionOS)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 20) {
                Button { openWindow(id: "assistant") } label: { Label("Assistant", systemImage: "sparkles") }
                if case .guide(let id)? = paths[section]?.last {
                    Button { openWindow(id: "guide", value: id) } label: { Label("Keep guide beside me", systemImage: "rectangle.on.rectangle") }
                }
                Button { activeSheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
            }
            .buttonStyle(.bordered).controlSize(.large).padding(16).glassBackgroundEffect()
        }
        #endif
        .onChange(of: scenePhase) { _, phase in if phase == .active { assistant.connection.refreshAvailability() } }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings: AdultSettingsView()
            case .reminder(let article): GuideReminderView(article: article)
            }
        }
        .alert("Couldn’t finish", isPresented: Binding(get: { store.actionIssue != nil }, set: { if !$0 { store.actionIssue = nil } })) {
            Button("OK", role: .cancel) { store.actionIssue = nil }
        } message: { Text(store.actionIssue ?? "Please try again.") }
        .onChange(of: store.requestedGuideID, initial: true) { _, id in
            guard let id else { return }
            section = .now
            paths[.now] = [.guide(id)]
            store.requestedGuideID = nil
        }
        .onChange(of: assistant.requestedPresentationID, initial: true) { _, id in
            if id != nil { section = .assistant; assistant.requestedPresentationID = nil }
        }
        .onChange(of: store.requestedAssistantActionID, initial: true) { _, id in
            guard let id, let plan = assistant.library.plans.first(where: { $0.actions.contains { $0.id == id } }) else { return }
            assistant.selectedPlanID = plan.id
            section = .assistant
            store.requestedAssistantActionID = nil
        }
        .onOpenURL { url in
            guard url.scheme == "howtoadult", url.host == "guide" else { return }
            store.openGuide(url.lastPathComponent)
        }
        .task {
            guard !assistant.isPrivateQA else { return }
            await store.activateNotifications()
            await store.refresh()
        }
        #if DEBUG
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if assistant.isPrivateQA && arguments.contains("--qa-assistant") { section = .assistant }
            if let tab = arguments.first(where: { $0.hasPrefix("--qa-tab=") }), let value = AdultSection(rawValue: String(tab.dropFirst(9))) { section = value }
            if let guide = arguments.first(where: { $0.hasPrefix("--qa-guide=") }) { paths[section] = [.guide(String(guide.dropFirst(11)))] }
        }
        #endif
    }

    private var sidebar: some View {
        List(selection: Binding<AdultSection?>(get: { section }, set: { if let value = $0 { section = value } })) {
            ForEach(AdultSection.allCases) { item in Label(item.rawValue, systemImage: item.symbol).tag(item) }
            Section("Topics") {
                ForEach(store.categories) { category in
                    Button { section = .explore; paths[.explore] = [.category(category.id)] } label: {
                        Label { Text(category.title) } icon: {
                            Image(systemName: category.symbol).foregroundStyle(CategoryStyle.of(category.id, colorKey: category.colorKey).tint)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar-" + category.id)
                }
            }
        }
        .navigationTitle("Library")
        .navigationSplitViewColumnWidth(min: typeSize.isAccessibilitySize ? 300 : 200, ideal: typeSize.isAccessibilitySize ? 340 : 240)
        .toolbar { settingsButton }
    }

    private func stack(for item: AdultSection) -> some View {
        NavigationStack(path: Binding(get: { paths[item] ?? [] }, set: { paths[item] = $0 })) {
            Group {
                switch item {
                case .now: NowView { section = .explore }
                case .explore: ExploreView(filter: $exploreFilter)
                case .passport: PassportStampsView()
                case .assistant: AdultAssistantView()
                }
            }
            .navigationDestination(for: AdultRoute.self) { route in
                switch route {
                case .guide(let id), .step(let id, _):
                    if let article = store.article(id) {
                        let stepID: String? = if case .step(_, let step) = route { step } else { nil }
                        GuideReaderView(article: article, onReminder: { activeSheet = .reminder(article) }, initialStepID: stepID)
                            .id(route)
                    } else {
                        ContentUnavailableView("Guide unavailable", systemImage: "book.closed")
                    }
                case .category(let id):
                    if let category = store.categories.first(where: { $0.id == id }) { CategoryView(category: category) }
                }
            }
            .toolbar { if !usesSidebar { settingsButton } }
        }
    }

    @ToolbarContentBuilder private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button { activeSheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
                .accessibilityIdentifier("open-settings")
        }
    }
}

private enum AdultSheet: Identifiable {
    case settings
    case reminder(AdultArticle)
    var id: String {
        switch self {
        case .settings: "settings"
        case .reminder(let article): "reminder-" + article.id
        }
    }
}

struct GuideIllustrationView: View {
    @Environment(AdultStore.self) private var store
    let illustration: GuideIllustration
    let revision: String
    @State private var image: CGImage?
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image {
                Image(image, scale: 1, label: Text(illustration.altText))
                    .resizable().scaledToFit().frame(maxWidth: .infinity)
                if !illustration.caption.isEmpty {
                    Text(illustration.caption).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup("Artwork credits") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(illustration.creator)
                        Text(illustration.license)
                        Text(illustration.provenance)
                    }.font(.caption).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 20)
            }
        }
        .accessibilityIdentifier("illustration-" + illustration.guideID + "-" + (illustration.stepID.isEmpty ? "overview" : illustration.stepID))
        .onDisappear { isVisible = false; image = nil }
        .task(id: illustration) {
            isVisible = true
            image = nil
            let loaded = await store.illustrationImage(illustration, revision: revision)
            guard !Task.isCancelled, isVisible else { return }
            image = loaded
        }
    }
}

struct GuideNotesEditor: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let article: AdultArticle
    @State private var notes = ""
    @State private var original = ""
    @State private var discard = false
    var body: some View {
        NavigationStack {
            TextEditor(text: $notes).padding(16).navigationTitle("My notes")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if notes == original { dismiss() } else { discard = true } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.saveNotes(notes, for: article.id, expectedNotes: original) { dismiss() } }.disabled(!store.canSave || notes.count > 50_000) }
                }
                .onAppear { original = store.progress(article.id).personalNotes ?? ""; notes = original }
                .confirmationDialog("Discard these changes?", isPresented: $discard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() }; Button("Keep editing", role: .cancel) { } }
                .alert("Couldn’t save notes", isPresented: Binding(get: { store.actionIssue != nil }, set: { if !$0 { store.actionIssue = nil } })) { Button("OK") { store.actionIssue = nil } } message: { Text(store.actionIssue ?? "Please try again.") }
        }.interactiveDismissDisabled(notes != original).frame(minWidth: 280, minHeight: 320)
    }
}

#if os(visionOS)
struct GuideWindowView: View {
    @Environment(AdultStore.self) private var store
    let guideID: String
    @State private var showsReminder = false

    var body: some View {
        NavigationStack {
            if let article = store.article(guideID) {
                GuideReaderView(article: article, onReminder: { showsReminder = true }, isDetached: true)
                    .sheet(isPresented: $showsReminder) { GuideReminderView(article: article) }
            } else {
                ContentUnavailableView("Guide unavailable", systemImage: "book.closed")
            }
        }
        .tint(AdultPalette.accent)
        .alert("Couldn’t finish", isPresented: Binding(get: { store.actionIssue != nil }, set: { if !$0 { store.actionIssue = nil } })) {
            Button("OK", role: .cancel) { store.actionIssue = nil }
        } message: { Text(store.actionIssue ?? "Please try again.") }
    }
}
#endif

private struct GuideReminderView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let article: AdultArticle
    @State private var date = Date().addingTimeInterval(3_600)
    @State private var sound = true

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(article.title).font(.headline) }
                Section {
                    DatePicker("When", selection: $date, in: Date().addingTimeInterval(60)...)
                    Toggle("Play a sound", isOn: $sound)
                }
                Section {
                    Button("In one hour") { date = Date().addingTimeInterval(3_600) }
                    Button("Tomorrow") { date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400) }
                }
                if let existing = store.progress(article.id).reminderDate, existing > Date() {
                    Section {
                        Button("Remove reminder", role: .destructive) {
                            if store.cancelReminder(article.id) { dismiss() }
                        }.disabled(store.isScheduling).accessibilityIdentifier("remove-reminder")
                    }
                }
                if let issue = store.actionIssue { Text(issue).foregroundStyle(.red) }
            }
            .navigationTitle("Remind me")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(store.isScheduling) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.isScheduling ? "Saving…" : "Save") {
                        Task { if await store.schedule(article, date: date, sound: sound) { dismiss() } }
                    }.disabled(store.isScheduling).accessibilityIdentifier("save-reminder")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 480, minHeight: 360)
        #endif
        .onAppear {
            if let existing = store.progress(article.id).reminderDate, existing > Date() { date = existing }
            sound = store.progress(article.id).reminderSound
        }
    }
}

private struct AdultSettingsView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                AskAISettingsSection()
                Section("Assistant") {
                    NavigationLink { AdultAssistantSettingsView() } label: { Label("AI and automation", systemImage: "sparkles") }
                }
                Section("Your library") {
                    LabeledContent("Guides", value: "\(store.articles.count)")
                    LabeledContent("Favorites", value: "\(store.articles.filter { store.progress($0.id).isSaved }.count)")
                    Text("Guides and checked steps stay available offline.").font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                    if store.canRefresh {
                        Button(store.isRefreshing ? "Checking…" : "Check for new guides") { Task { await store.refresh() } }
                            .disabled(store.isRefreshing)
                    }
                    if let issue = store.updateIssue { Text(issue).font(.subheadline) }
                    if let issue = store.storageIssue {
                        Text(issue).font(.subheadline)
                        Button("Retry opening saved guides") { Task { store.reloadLocalFiles(); await store.activateNotifications() } }
                    }
                }
                Section("About") {
                    Text("A pocket guide for everyday life.")
                    Text("Rules vary by location. Guides identify US-specific information and link to original sources.")
                        .font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                    Link("Privacy", destination: URL(string: "https://nathanfennel.com/how-to-adult/privacy.html")!)
                    Link("Support", destination: URL(string: "https://nathanfennel.com/how-to-adult/support.html")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 500, minHeight: 420)
        #endif
    }
}

enum AdultPalette {
    static let accent = Color("AccentColor")
    static let secondaryText = Color("SecondaryText")
    static let ink = Color.primary
    /// Caution text: dark amber on light grounds (≥4.5:1), system orange on dark.
    static let caution = Color.adaptive(light: Color(hex: 0x9A4A00), dark: .orange)
    #if os(visionOS)
    static let background = Color.clear
    static let surface = Color.white.opacity(0.08)
    #elseif os(macOS)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    #else
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    #endif
    static func category(_ key: String) -> Color {
        switch key {
        case "teal": .teal
        case "orange": .orange
        case "green": .green
        case "rose": .pink
        case "purple": .purple
        case "indigo": .indigo
        default: accent
        }
    }
}
