import SwiftUI
import Observation

struct AdultRootView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @State private var section: AdultSection = .now
    @State private var paths: [AdultSection: [AdultRoute]] = [:]
    @State private var exploreFilter = GuideFilter()
    @State private var activeSheet: AdultSheet?

    private var usesSidebar: Bool {
        #if os(macOS)
        true
        #else
        sizeClass != .compact
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            // Same thresholds as Fieldnotes: a sidebar from 680 points, tabs below that and at accessibility sizes.
            let split = usesSidebar && geometry.size.width >= 680 && !typeSize.isAccessibilitySize
            Group {
                if split {
                    if section == .assistant {
                        NavigationSplitView { sidebar } content: {
                            AdultPlanSidebar().navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 410)
                        } detail: { NavigationStack { AdultAssistantView() } }
                    } else {
                        NavigationSplitView { sidebar } detail: { stack(for: section, split: true) }
                    }
                } else {
                    TabView(selection: $section) {
                        ForEach(AdultSection.allCases) { item in
                            Group {
                                if item == .assistant {
                                    NavigationStack { AdultAssistantView().toolbar { settingsButton } }
                                } else { stack(for: item, split: false) }
                            }
                            .tabItem { Label(item.rawValue, systemImage: item.symbol) }
                            .tag(item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 1800).frame(maxWidth: .infinity)
        .background(AdultPalette.background)
        .tint(AdultPalette.accent)
        .foregroundStyle(AdultPalette.ink)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings: AdultSettingsView()
            case .reminder(let article): GuideReminderView(article: article)
            }
        }
        .alert("Couldn’t finish", isPresented: Binding(get: { store.actionIssue != nil }, set: { if !$0 { store.actionIssue = nil } })) {
            Button("OK", role: .cancel) { store.actionIssue = nil }
        } message: { Text(store.actionIssue ?? "Please try again.") }
        .onChange(of: scenePhase) { _, phase in if phase == .active { assistant.connection.refreshAvailability() } }
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
        .task(id: store.catalog?.revision) { if !assistant.isPrivateQA || ProcessInfo.processInfo.arguments.contains("--qa-library") { await store.refreshIllustrations() } }
        #if DEBUG
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if assistant.isPrivateQA && arguments.contains("--qa-assistant") { section = .assistant }
            if let tab = arguments.first(where: { $0.hasPrefix("--qa-tab=") }), let value = AdultSection(rawValue: String(tab.dropFirst(9))) { section = value }
            if let guide = arguments.first(where: { $0.hasPrefix("--qa-guide=") }) {
                // Deferred one tick: a split view's detail stack resets a path set before it appears.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    paths[section] = [.guide(String(guide.dropFirst(11)))]
                }
            }
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
        .scrollContentBackground(.hidden)
        .background(AdultPalette.background)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        .toolbar { settingsButton }
    }

    private func stack(for item: AdultSection, split: Bool) -> some View {
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
            .toolbar {
                if !split { settingsButton }
                #if os(iOS)
                if !split { ToolbarItem(placement: .principal) { FieldnotesWordmark() } }
                #endif
            }
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

struct GuideNotesEditor: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let article: AdultArticle
    @State private var notes = ""
    @State private var original = ""
    @State private var discard = false
    var body: some View {
        NavigationStack {
            TextEditor(text: $notes).scrollContentBackground(.hidden).padding(16).background(AdultPalette.background).foregroundStyle(AdultPalette.ink).navigationTitle("My notes")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if notes == original { dismiss() } else { discard = true } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.saveNotes(notes, for: article.id, expectedNotes: original) { dismiss() } }.disabled(!store.canSave || notes.count > 50_000) }
                }
                .onAppear { original = store.progress(article.id).personalNotes ?? ""; notes = original }
                .confirmationDialog("Discard these changes?", isPresented: $discard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() }; Button("Keep editing", role: .cancel) { } }
                .alert("Couldn’t save notes", isPresented: Binding(get: { store.actionIssue != nil }, set: { if !$0 { store.actionIssue = nil } })) { Button("OK") { store.actionIssue = nil } } message: { Text(store.actionIssue ?? "Please try again.") }
        }.tint(AdultPalette.accent).interactiveDismissDisabled(notes != original).frame(minWidth: 280, minHeight: 320)
    }
}

struct GuideIllustrationView: View {
    let illustration: GuideIllustration
    let url: URL?
    var compactPlate = false
    @State private var expanded = false
    @State private var fullSize = false
    @State private var attempt = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { descriptionButton; fullSizeButton }
                VStack(alignment: .leading, spacing: 4) { descriptionButton; fullSizeButton }
            }
            if expanded { Text(illustration.altText).fieldnotesBody().fixedSize(horizontal: false, vertical: true) }
            VerifiedGuideImage(illustration: illustration) { image in
                image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 3)).accessibilityLabel(illustration.altText)
            }.id("\(url?.absoluteString ?? "")-\(attempt)")
            if !compactPlate {
                if !illustration.caption.isEmpty { Text(illustration.caption).fieldnotesBody(size: 15) }
                Text(illustration.creator + " · " + illustration.license).font(.caption).foregroundStyle(AdultPalette.secondaryText)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $fullSize) { IllustrationViewer(illustration: illustration, url: url) }
        .accessibilityIdentifier("illustration-" + illustration.guideID + "-" + (illustration.stepID.isEmpty ? "hero" : illustration.stepID))
    }
    private var descriptionButton: some View {
        Button { expanded.toggle() } label: { Label("Image description", systemImage: expanded ? "chevron.up" : "text.alignleft").font(.subheadline).frame(minHeight: 44) }
            .accessibilityValue(expanded ? "Expanded" : "Collapsed").accessibilityIdentifier("image-description-" + illustration.guideID + "-" + illustration.stepID)
    }
    private var fullSizeButton: some View {
        Button { fullSize = true } label: { Label("View full size", systemImage: "arrow.up.left.and.arrow.down.right").font(.subheadline).frame(minHeight: 44) }
            .disabled(url == nil).accessibilityIdentifier("full-size-image-" + illustration.guideID + "-" + illustration.stepID)
    }
}

private struct IllustrationViewer: View {
    @Environment(\.dismiss) private var dismiss
    let illustration: GuideIllustration
    let url: URL?
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VerifiedGuideImage(illustration: illustration) { image in
                        image.resizable().scaledToFit().frame(width: max(1, geometry.size.width - 32) * zoom * pinch).padding(16).accessibilityLabel(illustration.altText)
                    }
                }
                .gesture(MagnificationGesture().updating($pinch) { value, state, _ in state = value }.onEnded { zoom = min(5, max(1, zoom * $0)) })
            }
            .background(AdultPalette.background)
            .navigationTitle("Illustration")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button { zoom = max(1, zoom - 0.5) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }.disabled(zoom <= 1)
                    Button { zoom = min(5, zoom + 0.5) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }.disabled(zoom >= 5)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
            }
        }.frame(minWidth: 320, idealWidth: 760, minHeight: 420)
    }
}

struct GuideReminderView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let article: AdultArticle
    @State private var date = Date().addingTimeInterval(3_600)
    @State private var sound = true
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(article.title).font(.headline) }.listRowBackground(AdultPalette.surface)
                Section {
                    DatePicker(selection: $date, in: Date().addingTimeInterval(60)...) { Text("When").foregroundStyle(AdultPalette.ink) }
                    Toggle(isOn: $sound) { Text("Play a sound").foregroundStyle(AdultPalette.ink) }
                }.listRowBackground(AdultPalette.surface)
                Section {
                    Button("In one hour") { date = Date().addingTimeInterval(3_600) }
                    Button("Tomorrow") { date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400) }
                }.listRowBackground(AdultPalette.surface)
                if let existing = store.progress(article.id).reminderDate, existing > Date() {
                    Section {
                        Button("Remove reminder", role: .destructive) { if store.cancelReminder(article.id) { dismiss() } }
                            .disabled(store.isScheduling).accessibilityIdentifier("remove-reminder")
                    }.listRowBackground(AdultPalette.surface)
                }
                if let issue = store.actionIssue { Text(issue).foregroundStyle(AdultPalette.ink).listRowBackground(AdultPalette.caution) }
            }
            .scrollContentBackground(.hidden).background(AdultPalette.background)
            .foregroundStyle(AdultPalette.ink).tint(AdultPalette.accent)
            .navigationTitle("Remind me")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(store.isScheduling) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.isScheduling ? "Saving…" : "Save") {
                        Task { if await store.schedule(article, date: date, sound: sound) { dismiss() } }
                    }.disabled(store.isScheduling).accessibilityIdentifier("save-reminder")
                }
            }
        }.tint(AdultPalette.accent).frame(minWidth: 320, idealWidth: 480, minHeight: 360)
        .onAppear {
            if let existing = store.progress(article.id).reminderDate, existing > Date() { date = existing }
            sound = store.progress(article.id).reminderSound
        }
    }
}

private struct AdultSettingsView: View {
    @AppStorage("adultAppearance") private var appearance = "system"
    @AppStorage("adultSettingsSection") private var selectedSection = "Appearance"
    @Environment(AdultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 680 {
                NavigationSplitView {
                    List(["Appearance", "Ask an AI", "Assistant", "Your library", "About"], id: \.self,
                         selection: Binding<String?>(get: { selectedSection }, set: { if let value = $0 { selectedSection = value } })) { section in
                        Text(section).tag(section)
                    }
                    .navigationTitle("Settings").navigationSplitViewColumnWidth(min: 180, ideal: 210)
                    .scrollContentBackground(.hidden).background(AdultPalette.background)
                } detail: {
                    NavigationStack { settingsForm(focused: true).navigationTitle(selectedSection).toolbar { doneButton } }
                }
            } else {
                NavigationStack { settingsForm(focused: false).navigationTitle("Settings").toolbar { doneButton } }
            }
        }.foregroundStyle(AdultPalette.ink).tint(AdultPalette.accent)
            .frame(minWidth: 320, idealWidth: 760, minHeight: 420)
    }
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
    }
    private func settingsForm(focused: Bool) -> some View {
        Form {
            if !focused || selectedSection == "Appearance" {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Text("Text size and motion follow your system accessibility settings.").font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                }.listRowBackground(AdultPalette.surface)
            }
            if !focused || selectedSection == "Ask an AI" {
                AskAISettingsSection().listRowBackground(AdultPalette.surface)
            }
            if !focused || selectedSection == "Assistant" {
                Section("Assistant") {
                    NavigationLink { AdultAssistantSettingsView() } label: { Label("AI and automation", systemImage: "sparkles") }
                }.listRowBackground(AdultPalette.surface)
            }
            if !focused || selectedSection == "Your library" {
                Section("Your library") {
                    LabeledContent("Guides") { Text("\(store.articles.count)").foregroundStyle(AdultPalette.secondaryText) }
                    LabeledContent("Favorites") { Text("\(store.articles.filter { store.progress($0.id).isSaved }.count)").foregroundStyle(AdultPalette.secondaryText) }
                    Text("Guides and checked steps stay available offline.").font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                    if store.canRefresh {
                        Button(store.isRefreshing ? "Checking…" : "Check for new guides") { Task { await store.refresh() } }.disabled(store.isRefreshing)
                    }
                    if let issue = store.updateIssue { Text(issue).font(.subheadline).foregroundStyle(AdultPalette.secondaryText) }
                    if let issue = store.storageIssue {
                        Text(issue).font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                        Button("Retry opening saved guides") { Task { store.reloadLocalFiles(); await store.activateNotifications() } }
                    }
                }.listRowBackground(AdultPalette.surface)
            }
            if !focused || selectedSection == "About" {
                Section("About") {
                    Text("A pocket guide for everyday life.")
                    Text("Rules vary by location. Guides identify US-specific information and link to original sources.")
                        .font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                    Link("Privacy", destination: URL(string: "https://nathanfennel.com/how-to-adult/privacy.html")!)
                    Link("Support", destination: URL(string: "https://nathanfennel.com/how-to-adult/support.html")!)
                }.listRowBackground(AdultPalette.surface)
            }
        }.scrollContentBackground(.hidden).background(AdultPalette.background)
            .foregroundStyle(AdultPalette.ink).tint(AdultPalette.accent)
    }
}

/// Main's bounded PNG/digest checks apply to every artwork surface, including zoom.
struct VerifiedGuideImage<Content: View, Placeholder: View>: View {
    @Environment(AdultStore.self) private var store
    let illustration: GuideIllustration
    @ViewBuilder let content: (Image) -> Content
    /// Compact surfaces (badges) show this instead of the loading and retry states.
    var placeholder: (() -> Placeholder)?
    @State private var pixels: CGImage?
    @State private var didLoad = false
    @State private var attempt = 0
    var body: some View {
        Group {
            if let pixels { content(Image(decorative: pixels, scale: 1)) }
            else if let placeholder { placeholder() }
            else if didLoad {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Illustration unavailable", systemImage: "photo").font(.headline)
                    Text(illustration.altText).fieldnotesBody(size: 15)
                    Button("Retry illustration") { attempt += 1 }.frame(minHeight: 44)
                }.padding(12).foregroundStyle(AdultPalette.secondaryText).frame(maxWidth: .infinity, alignment: .leading).background(AdultPalette.surface)
            } else { ProgressView("Loading illustration").font(.caption).foregroundStyle(AdultPalette.secondaryText) }
        }.task(id: "\(store.catalog?.revision ?? "")/\(illustration.assetSHA256)/\(attempt)") {
            pixels = nil; didLoad = false
            if let revision = store.catalog?.revision { pixels = await store.illustrationImage(illustration, revision: revision) }
            didLoad = true
        }
    }
}

extension VerifiedGuideImage where Placeholder == EmptyView {
    init(illustration: GuideIllustration, @ViewBuilder content: @escaping (Image) -> Content) {
        self.illustration = illustration
        self.content = content
        self.placeholder = nil
    }
}

extension VerifiedGuideImage {
    init(illustration: GuideIllustration, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.illustration = illustration
        self.content = content
        self.placeholder = placeholder
    }
}
