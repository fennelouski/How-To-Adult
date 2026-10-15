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
    @State private var assistantPath: [String] = []
    @State private var assistantFilters = GuideCollectionState()
    @State private var section: AdultSection = .browse
    @State private var selectedID: String?
    @State private var browsePath: [String] = []
    @State private var savedPath: [String] = []
    @State private var reminderPath: [String] = []
    @State private var browseFilters = GuideCollectionState()
    @State private var savedFilters = GuideCollectionState()
    @State private var reminderFilters = GuideCollectionState()
    @State private var activeSheet: AdultSheet?

    private var usesSidebar: Bool {
        #if os(macOS)
        true
        #else
        sizeClass != .compact
        #endif
    }

    var body: some View {
        @Bindable var store = store
        GeometryReader { geometry in
            Group {
            if usesSidebar && geometry.size.width >= 1000 && !typeSize.isAccessibilitySize {
                NavigationSplitView {
                    List(AdultSection.allCases, selection: Binding<AdultSection?>(get: { section }, set: { if let value = $0 { section = value } })) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                    .navigationTitle("Library")
                    .scrollContentBackground(.hidden)
                    .background(AdultPalette.background)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 240)
                    .toolbar { settingsButton }
                } content: {
                    sectionCollection
                        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 410)
                } detail: {
                    NavigationStack { readerSelection }
                }
            } else if usesSidebar && geometry.size.width >= 680 && !typeSize.isAccessibilitySize {
                NavigationSplitView {
                    sectionCollection
                        .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 400)
                        .toolbar {
                            settingsButton
                            ToolbarItem { sectionMenu }
                        }
                } detail: {
                    NavigationStack { readerSelection }
                }
            } else {
                TabView(selection: $section) {
                    ForEach(AdultSection.allCases) { item in
                        NavigationStack(path: navigationPath(for: item)) {
                            Group {
                                if item == .assistant { AdultAssistantView() }
                                else { GuideCollectionView(section: item, filters: collectionState(for: item), selectedID: $selectedID, isSidebar: false, onBrowse: { section = .browse }) }
                            }
                                .navigationDestination(for: String.self) { id in
                                    if let article = store.article(id) { GuideReaderView(article: article) { activeSheet = .reminder(article) } }
                                }
                                .toolbar {
                                    settingsButton
                                    ToolbarItem(placement: .principal) { FieldnotesWordmark() }
                                }
                        }
                        .tabItem { Label(item.rawValue, systemImage: item.symbol) }
                        .tag(item)
                    }
                }
            }
        }
            .onChange(of: navigationMode(width: geometry.size.width)) { old, new in
                if section != .assistant, old != .compact, new == .compact, let selectedID {
                    navigationPath(for: section).wrappedValue = [selectedID]
                } else if section != .assistant, old == .compact, new != .compact, let current = navigationPath(for: section).wrappedValue.last {
                    selectedID = current
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
            section = .browse
            selectedID = id
            browsePath = [id]
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
        .onChange(of: browsePath) { _, path in if section == .browse { preserveSelection(path) } }
        .onChange(of: savedPath) { _, path in if section == .saved { preserveSelection(path) } }
        .onChange(of: reminderPath) { _, path in if section == .reminders { preserveSelection(path) } }
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
        .onAppear { if assistant.isPrivateQA && ProcessInfo.processInfo.arguments.contains("--qa-assistant") { section = .assistant } }
        #endif
    }

    private enum NavigationMode: Equatable { case compact, double, triple }
    private func navigationMode(width: CGFloat) -> NavigationMode {
        guard usesSidebar && !typeSize.isAccessibilitySize else { return .compact }
        return width >= 1000 ? .triple : width >= 680 ? .double : .compact
    }
    private func collectionState(for section: AdultSection) -> GuideCollectionState {
        switch section { case .browse: browseFilters; case .saved: savedFilters; case .reminders: reminderFilters; case .assistant: assistantFilters }
    }

    @ViewBuilder private var sectionCollection: some View {
        if section == .assistant { AdultPlanSidebar() }
        else { GuideCollectionView(section: section, filters: collectionState(for: section), selectedID: $selectedID, isSidebar: true, onBrowse: { section = .browse }) }
    }
    @ViewBuilder private var readerSelection: some View {
        if section == .assistant { AdultAssistantView() }
        else if let selectedID, let article = store.article(selectedID) {
            GuideReaderView(article: article) { activeSheet = .reminder(article) }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                FieldnotesHeading("A useful next step.", size: 34, relativeTo: .largeTitle)
                Text("Choose a guide to get started.").fieldnotesBody().foregroundStyle(AdultPalette.secondaryText)
            }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(AdultPalette.background)
        }
    }
    private var sectionMenu: some View {
        Menu {
            Picker("Library section", selection: $section) {
                ForEach(AdultSection.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
        } label: { Label(section.rawValue, systemImage: section.symbol) }
    }

    @ToolbarContentBuilder private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button { activeSheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
                .accessibilityIdentifier("open-settings")
        }
    }

    private func navigationPath(for section: AdultSection) -> Binding<[String]> {
        switch section {
        case .browse: $browsePath
        case .saved: $savedPath
        case .reminders: $reminderPath
        case .assistant: $assistantPath
        }
    }

    private func preserveSelection(_ path: [String]) {
        if let id = path.last { selectedID = id }
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

@MainActor @Observable final class GuideCollectionState {
    var query = ""
    var categoryID: String?
    var generalOnly = false
    var inProgressOnly = false
    var showsAllTopics = false
}

struct GuideCollectionView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dynamicTypeSize) private var typeSize
    let section: AdultSection
    @Bindable var filters: GuideCollectionState
    @Binding var selectedID: String?
    let isSidebar: Bool
    var onBrowse: () -> Void = {}
    @FocusState private var searchFocused: Bool

    private var filtered: [AdultArticle] {
        let base = section == .reminders ? store.upcoming : store.articles
        return base.filter {
            (section != .saved || store.progress($0.id).isSaved) &&
            (filters.categoryID == nil || $0.categoryID == filters.categoryID) &&
            (!filters.generalOnly || $0.jurisdiction == "General") && $0.matches(filters.query)
        }
    }
    private var isDiscovery: Bool { section == .browse && filters.query.isEmpty && filters.categoryID == nil && !filters.generalOnly && !filters.showsAllTopics }
    private var continuing: [AdultArticle] {
        filtered.filter { let count = store.progress($0.id).completedCount(in: $0); return count > 0 && count < $0.steps.count }
    }
    private var remaining: [AdultArticle] { filtered.filter { article in !continuing.contains(where: { $0.id == article.id }) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AdultPrivateQABanner()
                if let issue = store.storageIssue {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Saved guides need attention", systemImage: "exclamationmark.triangle").font(.headline)
                        Text(issue).fieldnotesBody()
                        Button("Retry opening saved guides") { Task { store.reloadLocalFiles(); await store.activateNotifications() } }
                            .frame(minHeight: 44)
                    }.padding(16).background(AdultPalette.caution, in: RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 12) {
                    FieldnotesHeading(title, size: 36, relativeTo: .largeTitle)
                    Text(subtitle).fieldnotesBody(size: 15).foregroundStyle(AdultPalette.secondaryText)
                }
                if section != .reminders { searchField }
                if isDiscovery {
                    if let article = store.article("repair-a-short-loose-cotton-hem") ?? store.articles.first {
                        guideLink(article) { FeaturedGuide(article: article) }
                            .accessibilityIdentifier("featured-guide")
                    }
                    topicIndex
                    guideList(filtered, title: "Pick a place to start")
                } else {
                    if section == .browse { filterControls }
                    if section == .saved {
                        Picker("Saved guides", selection: $filters.inProgressOnly) {
                            Text("All saved").tag(false)
                            Text("In progress").tag(true)
                        }.pickerStyle(.segmented)
                        if filtered.isEmpty { emptyState }
                        else if filters.inProgressOnly && continuing.isEmpty {
                            Text("No saved guides in progress yet. Check a step in a guide to pick up where you left off.")
                                .fieldnotesBody().foregroundStyle(AdultPalette.secondaryText)
                        } else {
                            if !continuing.isEmpty { guideList(continuing, title: "Keep going") }
                            if !filters.inProgressOnly && !remaining.isEmpty { guideList(remaining, title: "For later") }
                        }
                    } else if filtered.isEmpty { emptyState }
                    else { guideList(filtered, title: filters.categoryID.flatMap { id in store.categories.first { $0.id == id }?.title }) }
                }
                if store.isRefreshing {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Checking for new guides…").font(.caption) }
                        .foregroundStyle(AdultPalette.secondaryText)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 24).padding(.bottom, 16)
            .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .foregroundStyle(AdultPalette.ink)
        .navigationTitle(isSidebar ? section.rawValue : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AdultPalette.background, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        #endif
        .refreshable { await store.refresh() }
        .accessibilityIdentifier("guide-collection")
    }

    private var title: String {
        switch section {
        case .browse: isDiscovery ? "Life comes\nwith questions." : "Find a useful\nnext step."
        case .saved: "Your useful\nlibrary."
        case .reminders: "A nudge\nfor later."
        case .assistant: "A doable plan."
        }
    }
    private var subtitle: String {
        switch section {
        case .browse: "A useful next step is closer than you think."
        case .saved: "Saved for the moment you need it."
        case .reminders: "Your guides, at the right time."
        case .assistant: "A little help with everyday life."
        }
    }
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").accessibilityHidden(true)
            TextField("", text: $filters.query, prompt: Text("What would you like to know?").foregroundStyle(AdultPalette.secondaryText))
                .textFieldStyle(.plain).fieldnotesBody(size: 15)
                .focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                .accessibilityLabel("Search guides").accessibilityIdentifier("guide-search")
            if !filters.query.isEmpty {
                Button { filters.query = "" } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .foregroundStyle(AdultPalette.secondaryText)
        .padding(.leading, 14).padding(.trailing, filters.query.isEmpty ? 14 : 0)
        .frame(minHeight: 48)
        .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 10))
    }
    private var topicIndex: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FieldnotesHeading("Find your way", size: 25)
                Spacer(minLength: 8)
                Button("All topics") { filters.categoryID = nil; filters.generalOnly = false; filters.showsAllTopics = true }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 0) {
                ForEach(store.categories) { category in
                    Button { filters.categoryID = category.id } label: {
                        HStack(spacing: 10) {
                            Image(systemName: category.symbol).frame(width: 22).accessibilityHidden(true)
                            Text(category.title).fieldnotesBody(size: 15)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                        }.foregroundStyle(AdultPalette.ink).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    .overlay(alignment: .bottom) { FieldnotesRule() }
                    .accessibilityIdentifier("topic-" + category.id)
                }
            }
        }
    }
    private var filterControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { categoryPicker; scopePicker; Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: 8) { categoryPicker; scopePicker }
        }
    }
    private var categoryPicker: some View {
        Menu {
            Picker("Topic", selection: $filters.categoryID) {
                Text("All topics").tag(String?.none)
                ForEach(store.categories) { category in Label(category.title, systemImage: category.symbol).tag(Optional(category.id)) }
            }
            Button("Clear filters") { filters.categoryID = nil; filters.generalOnly = false }
        } label: {
            Label(store.categories.first(where: { $0.id == filters.categoryID })?.title ?? "All topics", systemImage: "line.3.horizontal.decrease")
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.accessibilityIdentifier("category-filter")
    }
    private var scopePicker: some View {
        Menu {
            Picker("Location", selection: $filters.generalOnly) {
                Text("All regions").tag(false)
                Text("General guidance").tag(true)
            }
        } label: {
            Label(filters.generalOnly ? "General guidance" : "All regions", systemImage: "globe")
                .font(.subheadline).frame(minHeight: 44)
        }.accessibilityIdentifier("region-filter")
    }
    private func guideList(_ articles: [AdultArticle], title: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { FieldnotesHeading(title, size: 25) }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(articles) { article in
                    guideLink(article) { GuideRow(article: article, showsReminder: section == .reminders) }
                        .background(isSidebar && selectedID == article.id ? AdultPalette.surface : .clear)
                    FieldnotesRule()
                }
            }
        }
    }
    @ViewBuilder private func guideLink<Content: View>(_ article: AdultArticle, @ViewBuilder content: () -> Content) -> some View {
        if isSidebar { Button { selectedID = article.id } label: { content() }.buttonStyle(.plain) }
        else { NavigationLink(value: article.id) { content() }.buttonStyle(.plain) }
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: section == .saved ? "book" : section.symbol).font(.largeTitle).accessibilityHidden(true)
            FieldnotesHeading(section == .saved && filters.query.isEmpty ? "Keep a useful guide handy" : section == .reminders ? "Make room for later" : "No guides found", size: 25)
            Text(section == .saved && filters.query.isEmpty ? "Save a guide and it will be here when you need it." : section == .reminders ? "Open a guide and choose Remind me to set a time." : "Try another search, topic or region.")
                .fieldnotesBody().foregroundStyle(AdultPalette.secondaryText)
            if section == .saved && filters.query.isEmpty { Button("Browse guides", action: onBrowse).frame(minHeight: 44) }
            else if section != .reminders { Button("Clear filters") { filters.categoryID = nil; filters.generalOnly = false }.frame(minHeight: 44) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20)
    }
}

private struct FeaturedGuide: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var availableWidth: CGFloat = 0
    let article: AdultArticle
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if typeSize.isAccessibilitySize || availableWidth < 320 {
                VStack(alignment: .leading, spacing: 20) { information; artwork.frame(maxWidth: 250) }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    information.frame(maxWidth: .infinity, alignment: .leading)
                    artwork.frame(width: 146).aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
            }
            FieldnotesRule()
        }.foregroundStyle(AdultPalette.ink).contentShape(Rectangle())
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in availableWidth = width }
            }
        }
    }
    private var information: some View {
        VStack(alignment: .leading, spacing: 22) {
            FieldnotesHeading(article.title, size: 27, relativeTo: .title)
            Text("\(article.minutes) min · \(article.steps.count) steps").fieldnotesBody(size: 15).foregroundStyle(AdultPalette.secondaryText)
            Label("Open guide", systemImage: "arrow.right").font(.body.weight(.semibold)).foregroundStyle(AdultPalette.accent).frame(minHeight: 44)
        }
    }
    @ViewBuilder private var artwork: some View {
        if let illustration = store.illustration(guideID: article.id) {
            VerifiedGuideImage(illustration: illustration) { image in
                image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 3)).accessibilityLabel(illustration.altText)
            }
        }
    }
}

private struct GuideRow: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle
    let showsReminder: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: article.symbol).font(.body).frame(width: 24, height: 24).foregroundStyle(AdultPalette.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(article.title).fieldnotesBody(weight: .semibold).foregroundStyle(AdultPalette.ink)
                Text(article.summary).fieldnotesBody(size: 15).foregroundStyle(AdultPalette.secondaryText)
                if showsReminder, let date = store.progress(article.id).reminderDate {
                    Label { Text(date, format: .dateTime.month(.abbreviated).day().hour().minute()) } icon: { Image(systemName: "bell") }
                        .font(.caption).foregroundStyle(AdultPalette.accent)
                } else {
                    Text("\(article.minutes) min · \(article.steps.count) steps" + (article.jurisdiction == "General" ? "" : " · " + article.jurisdiction))
                        .font(.caption).foregroundStyle(AdultPalette.secondaryText)
                }
                let completed = store.progress(article.id).completedCount(in: article)
                if completed > 0 {
                    Text("\(completed) of \(article.steps.count) steps checked").font(.caption).foregroundStyle(AdultPalette.ink)
                    GuideProgressLine(article: article).padding(.top, 3)
                }
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(.vertical, 18).contentShape(Rectangle())
        .accessibilityElement(children: .combine).accessibilityIdentifier("guide-" + article.id)
    }
}

struct GuideReaderView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var readerWidth: CGFloat = 0
    let article: AdultArticle
    let onReminder: () -> Void
    var isPassportReview = false
    @State private var editingNotes = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if usesSpread, let illustration = store.illustration(guideID: article.id) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 24) {
                            introduction.frame(maxWidth: .infinity, alignment: .leading)
                            GuideIllustrationView(illustration: illustration, url: store.illustrationURL(illustration), compactPlate: true)
                                .frame(width: readerWidth >= 600 ? 200 : 168)
                                .accessibilityElement(children: .contain).accessibilitySortPriority(3)
                        }
                        if !illustration.caption.isEmpty { Text(illustration.caption).fieldnotesBody(size: 15).foregroundStyle(AdultPalette.secondaryText).accessibilitySortPriority(3) }
                        Text(illustration.creator + " · " + illustration.license).font(.caption).foregroundStyle(AdultPalette.secondaryText).accessibilitySortPriority(3)
                    }
                } else {
                    introduction
                }
                if !article.cautions.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Before you begin", systemImage: "checkmark.shield").font(.headline)
                        ForEach(article.cautions, id: \.self) { Text($0).fieldnotesBody(size: 15) }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AdultPalette.caution, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityElement(children: .contain).accessibilitySortPriority(5)
                }
                if !article.tools.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(article.tools, id: \.self) { Text($0).fieldnotesBody() }
                        }.padding(.top, 12)
                    } label: { FieldnotesHeading("What you’ll need", size: 25) }
                    .accessibilityElement(children: .contain).accessibilitySortPriority(4)
                }
                if !usesSpread, let illustration = store.illustration(guideID: article.id) {
                    GuideIllustrationView(illustration: illustration, url: store.illustrationURL(illustration))
                        .accessibilityElement(children: .contain).accessibilitySortPriority(3)
                }
                VStack(alignment: .leading, spacing: 16) {
                    FieldnotesHeading("One step at a time", size: 25)
                    Text("\(store.progress(article.id).completedCount(in: article)) of \(article.steps.count) steps checked")
                        .font(.caption).foregroundStyle(AdultPalette.secondaryText)
                    GuideProgressLine(article: article)
                    ForEach(article.steps) { step in
                        VStack(alignment: .leading, spacing: 0) {
                            GuideStepRow(article: article, step: step)
                            if let illustration = store.illustration(guideID: article.id, stepID: step.id) {
                                GuideIllustrationView(illustration: illustration, url: store.illustrationURL(illustration)).padding(.bottom, 20)
                            }
                            FieldnotesRule()
                        }
                    }
                }
                if !article.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        FieldnotesHeading("Go to the source", size: 25)
                        ForEach(article.sources, id: \.url) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) { Label(source.title, systemImage: "arrow.up.right.square").fieldnotesBody().fixedSize(horizontal: false, vertical: true).frame(minHeight: 44) }
                            }
                        }
                    }
                }
                personalReference
                Text("Reviewed \(article.updatedAt)").font(.caption).foregroundStyle(AdultPalette.secondaryText)
                if let date = store.progress(article.id).reminderDate, date > Date() {
                    VStack(alignment: .leading, spacing: 10) {
                        Label { Text(date, format: .dateTime.month().day().hour().minute()) } icon: { Image(systemName: "bell.badge") }
                        Button("Remove reminder", role: .destructive) { store.cancelReminder(article.id) }.frame(minHeight: 44).accessibilityIdentifier("remove-guide-reminder")
                    }.font(.subheadline)
                }
            }.padding(24).padding(.bottom, 16).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background).foregroundStyle(AdultPalette.ink)
        .navigationTitle(store.category(article)?.title ?? "Guide")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AdultPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { store.toggleSaved(article.id) } label: {
                    Label(store.progress(article.id).isSaved ? "Unsave guide" : "Save guide", systemImage: store.progress(article.id).isSaved ? "bookmark.fill" : "bookmark")
                }.disabled(!store.canSave).accessibilityIdentifier("save-guide")
                if !isPassportReview { Button(action: onReminder) { Label("Remind me", systemImage: "bell") }.disabled(!store.canSave).accessibilityIdentifier("remind-guide")
                ShareLink(item: article.shareText) }
            }
        }.accessibilityIdentifier("guide-reader")
        .sheet(isPresented: $editingNotes) { GuideNotesEditor(article: article) }
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { readerWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in readerWidth = width }
            }
        }
    }
    private var usesSpread: Bool { readerWidth >= 520 && !typeSize.isAccessibilitySize }
    private var personalReference: some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldnotesRule()
            FieldnotesHeading("Make this yours", size: 25)
            Text("My rating").font(.headline)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { stars in
                    let selected = store.progress(article.id).rating ?? 0
                    Button { store.rate(article.id, stars: selected == stars ? nil : stars) } label: {
                        Image(systemName: selected >= stars ? "star.fill" : "star").font(.title2)
                            .foregroundStyle(selected >= stars ? AdultPalette.accent : AdultPalette.secondaryText).frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain).disabled(!store.canSave)
                        .accessibilityLabel("Rate \(stars) out of 5").accessibilityValue(selected == stars ? "Selected" : "Not selected")
                }
            }
            if let notes = store.progress(article.id).personalNotes, !notes.isEmpty {
                Text(notes).font(.body).lineLimit(4).textSelection(.enabled)
            }
            Button { editingNotes = true } label: {
                Label(store.progress(article.id).personalNotes == nil ? "Add my notes" : "Open my notes", systemImage: "square.and.pencil").font(.headline).padding(.vertical, 6)
            }.disabled(!store.canSave).accessibilityIdentifier("guide-personal-notes")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 15) {
                    FieldnotesHeading(article.title, size: 34, relativeTo: .largeTitle)
                    Text((store.category(article)?.title ?? "Guide") + " · " + (article.jurisdiction == "General" ? "General guidance" : article.jurisdiction + " rules"))
                        .font(.caption).foregroundStyle(AdultPalette.secondaryText)
                    Text(article.summary).fieldnotesBody().foregroundStyle(AdultPalette.secondaryText)
                    Text("\(article.minutes) min · \(article.steps.count) steps").font(.caption).foregroundStyle(AdultPalette.secondaryText)
            if let notice = article.adviceNotice { Text(notice).fieldnotesBody(size: 15).foregroundStyle(AdultPalette.secondaryText) }
            if !isPassportReview {
                Button { assistant.prepare(article) } label: { Label("Help me do this", systemImage: "sparkles").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }
                    .accessibilityIdentifier("guide-assistant")
            }
                }
                .accessibilityElement(children: .contain).accessibilitySortPriority(6)
    }
}

private struct GuideNotesEditor: View {
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

private struct GuideProgressLine: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle
    var body: some View {
        HStack(spacing: 4) {
            ForEach(article.steps) { step in
                RoundedRectangle(cornerRadius: 1).fill(store.progress(article.id).isChecked(step) ? AdultPalette.accent : AdultPalette.rule).frame(height: 3)
            }
        }.accessibilityHidden(true)
    }
}

private struct GuideIllustrationView: View {
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

private struct GuideStepRow: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let article: AdultArticle
    let step: GuideStep
    var body: some View {
        let checked = store.progress(article.id).isChecked(step)
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { store.toggleStep(step, in: article) }
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle").font(.system(size: 29, weight: .regular))
                    .foregroundStyle(checked ? AdultPalette.accent : AdultPalette.secondaryText).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain).disabled(!store.canSave)
            .accessibilityLabel(step.title).accessibilityValue("\(checked ? "Checked" : "Not checked"), step \((article.steps.firstIndex(of: step) ?? 0) + 1) of \(article.steps.count)")
            .accessibilityHint("Changes completion").accessibilityIdentifier("step-" + step.id)
            VStack(alignment: .leading, spacing: 9) {
                Text(step.title).fieldnotesBody(weight: .semibold)
                Text(step.body).fieldnotesBody().foregroundStyle(AdultPalette.secondaryText)
            }.padding(.top, 9).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(AdultPalette.ink).padding(.vertical, 18)
    }
}

private struct GuideReminderView: View {
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
                    List(["Appearance", "Assistant", "Your library", "About"], id: \.self,
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
            if !focused || selectedSection == "Assistant" {
                Section("Assistant") {
                    NavigationLink { AdultAssistantSettingsView() } label: { Label("AI and automation", systemImage: "sparkles") }
                }.listRowBackground(AdultPalette.surface)
            }
            if !focused || selectedSection == "Your library" {
                Section("Your library") {
                    LabeledContent("Guides") { Text("\(store.articles.count)").foregroundStyle(AdultPalette.secondaryText) }
                    LabeledContent("Saved") { Text("\(store.articles.filter { store.progress($0.id).isSaved }.count)").foregroundStyle(AdultPalette.secondaryText) }
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
private struct VerifiedGuideImage<Content: View>: View {
    @Environment(AdultStore.self) private var store
    let illustration: GuideIllustration
    @ViewBuilder let content: (Image) -> Content
    @State private var pixels: CGImage?
    @State private var didLoad = false
    @State private var attempt = 0
    var body: some View {
        Group {
            if let pixels { content(Image(decorative: pixels, scale: 1)) }
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
