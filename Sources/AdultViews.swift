import SwiftUI

struct AdultRootView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var section: AdultSection = .browse
    @State private var selectedID: String?
    @State private var browsePath: [String] = []
    @State private var savedPath: [String] = []
    @State private var reminderPath: [String] = []
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
        Group {
            if usesSidebar {
                NavigationSplitView {
                    List(AdultSection.allCases, selection: Binding<AdultSection?>(get: { section }, set: { if let value = $0 { section = value } })) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                    .navigationTitle("Library")
                    .navigationSplitViewColumnWidth(min: typeSize.isAccessibilitySize ? 300 : 180, ideal: typeSize.isAccessibilitySize ? 340 : 220)
                    .toolbar { settingsButton }
                } content: {
                    GuideCollectionView(section: section, selectedID: $selectedID, isSidebar: true)
                        .navigationSplitViewColumnWidth(min: 300, ideal: 410, max: 520)
                } detail: {
                    NavigationStack {
                        if let selectedID, let article = store.article(selectedID) {
                            GuideReaderView(article: article) { activeSheet = .reminder(article) }
                        } else {
                            ContentUnavailableView("A hand with everyday life", systemImage: "book.pages", description: Text("Choose a guide to get started."))
                        }
                    }
                }
            } else {
                TabView(selection: $section) {
                    ForEach(AdultSection.allCases) { item in
                        NavigationStack(path: navigationPath(for: item)) {
                            GuideCollectionView(section: item, selectedID: $selectedID, isSidebar: false)
                                .navigationDestination(for: String.self) { id in
                                    if let article = store.article(id) { GuideReaderView(article: article) { activeSheet = .reminder(article) } }
                                }
                                .toolbar { settingsButton }
                        }
                        .tabItem { Label(item.rawValue, systemImage: item.symbol) }
                        .tag(item)
                    }
                }
            }
        }
        .tint(AdultPalette.accent)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings: AdultSettingsView()
            case .reminder(let article): GuideReminderView(article: article)
            }
        }
        .alert("Couldn’t finish", isPresented: Binding(get: { store.actionIssue != nil }, set: { if !$0 { store.actionIssue = nil } })) {
            Button("OK", role: .cancel) { store.actionIssue = nil }
        } message: { Text(store.actionIssue ?? "Please try again.") }
        .onChange(of: store.requestedGuideID) { _, id in
            guard let id else { return }
            section = .browse
            selectedID = id
            browsePath = [id]
            store.requestedGuideID = nil
        }
        .onChange(of: browsePath) { _, path in if section == .browse { preserveSelection(path) } }
        .onChange(of: savedPath) { _, path in if section == .saved { preserveSelection(path) } }
        .onChange(of: reminderPath) { _, path in if section == .reminders { preserveSelection(path) } }
        .onChange(of: usesSidebar) { _, sidebar in
            if !sidebar, let selectedID { navigationPath(for: section).wrappedValue = [selectedID] }
        }
        .onOpenURL { url in
            guard url.scheme == "howtoadult", url.host == "guide" else { return }
            store.openGuide(url.lastPathComponent)
        }
        .task {
            await store.activateNotifications()
            await store.refresh()
        }
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

struct GuideCollectionView: View {
    @Environment(AdultStore.self) private var store
    let section: AdultSection
    @Binding var selectedID: String?
    let isSidebar: Bool
    @State private var query = ""
    @State private var categoryID: String?
    @State private var generalOnly = false

    private var filtered: [AdultArticle] {
        let base = section == .reminders ? store.upcoming : store.articles
        return base.filter {
            (section != .saved || store.progress($0.id).isSaved) &&
            (categoryID == nil || $0.categoryID == categoryID) &&
            (!generalOnly || $0.jurisdiction == "General") && $0.matches(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let issue = store.storageIssue {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Saved guides need attention", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                        Text(issue).font(.subheadline)
                        Button("Retry opening saved guides") { Task { store.reloadLocalFiles(); await store.activateNotifications() } }
                    }
                    .padding().background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                if section == .browse && query.isEmpty && categoryID == nil {
                    intro
                }
                if section != .reminders { filters }
                if filtered.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { article in
                            articleLink(article)
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 22)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .navigationTitle(section == .browse ? (isSidebar ? "Guides" : "How to Adult") : section.rawValue)
        .searchable(text: $query, prompt: "Laundry, money, making friends…")
        .refreshable { await store.refresh() }
        .onChange(of: section) { _, _ in query = ""; categoryID = nil }
        .accessibilityIdentifier("guide-collection")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Life comes with questions.")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(AdultPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("A useful next step is closer than you think.")
                .font(.body).foregroundStyle(.secondary)
            if let article = store.articles.first(where: { $0.id == "wash-your-first-load" }) ?? store.articles.first {
                Group {
                    if isSidebar {
                        Button { selectedID = article.id } label: { featured(article) }
                    } else {
                        NavigationLink(value: article.id) { featured(article) }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("featured-guide")
            }
        }
    }

    private func featured(_ article: AdultArticle) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(article.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                Text(article.summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Label("Open guide", systemImage: "arrow.right").font(.headline)
            }
            Spacer(minLength: 0)
            Image(systemName: article.symbol).font(.largeTitle).accessibilityHidden(true)
        }
        .foregroundStyle(.white).padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.07, green: 0.23, blue: 0.45), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var filters: some View {
        ViewThatFits(in: .horizontal) {
            HStack { categoryPicker; Spacer(minLength: 8); scopePicker }
            VStack(alignment: .leading, spacing: 12) { categoryPicker; scopePicker }
        }
    }

    private var categoryPicker: some View {
        Menu {
            Picker("Topic", selection: $categoryID) {
                Text("All topics").tag(String?.none)
                ForEach(store.categories) { category in
                    Label(category.title, systemImage: category.symbol).tag(Optional(category.id))
                }
            }
        } label: {
            Label(store.categories.first(where: { $0.id == categoryID })?.title ?? "All topics", systemImage: "line.3.horizontal.decrease.circle")
                .font(.headline).padding(.vertical, 10)
        }.accessibilityIdentifier("category-filter")
    }

    private var scopePicker: some View {
        Menu {
            Picker("Location", selection: $generalOnly) {
                Text("All guides").tag(false)
                Text("Everyday guides").tag(true)
            }
        } label: {
            Label(generalOnly ? "Everyday guides" : "All regions", systemImage: "globe")
                .font(.subheadline).padding(.vertical, 10)
        }.accessibilityIdentifier("region-filter")
    }

    @ViewBuilder private func articleLink(_ article: AdultArticle) -> some View {
        if isSidebar {
            Button { selectedID = article.id } label: { GuideRow(article: article, showsReminder: section == .reminders) }
                .buttonStyle(.plain)
                .background(selectedID == article.id ? AdultPalette.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 12))
        } else {
            NavigationLink(value: article.id) { GuideRow(article: article, showsReminder: section == .reminders) }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if section == .saved {
            ContentUnavailableView("Keep a useful guide close", systemImage: "bookmark", description: Text("Tap the bookmark in any guide to save it here."))
        } else if section == .reminders {
            ContentUnavailableView("A nudge for later", systemImage: "bell", description: Text("Open a guide and tap the bell to choose a time."))
        } else {
            ContentUnavailableView("No guides here yet", systemImage: "books.vertical", description: Text("Try a different topic or region."))
        }
    }
}

private struct GuideRow: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle
    let showsReminder: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: article.symbol)
                .font(.title2.weight(.medium)).frame(width: 42, height: 48)
                .foregroundStyle(AdultPalette.category(store.category(article)?.colorKey ?? "blue"))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(article.title).font(.headline).foregroundStyle(.primary)
                Text(article.summary).font(.subheadline).foregroundStyle(.secondary)
                if showsReminder, let date = store.progress(article.id).reminderDate {
                    Label { Text(date, format: .dateTime.month(.abbreviated).day().hour().minute()) } icon: { Image(systemName: "bell") }
                        .font(.caption).foregroundStyle(AdultPalette.accent)
                } else {
                    Text("About \(article.minutes) min · \(article.steps.count) steps" + (article.jurisdiction == "General" ? "" : " · " + article.jurisdiction))
                        .font(.caption).foregroundStyle(.secondary)
                }
                let completed = store.progress(article.id).completedCount(in: article)
                if completed > 0 {
                    Label("\(completed) of \(article.steps.count) done", systemImage: completed == article.steps.count ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption.weight(.semibold)).foregroundStyle(AdultPalette.accent)
                }
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 6).accessibilityHidden(true)
        }
        .padding(.vertical, 18).padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("guide-" + article.id)
    }
}

struct GuideReaderView: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle
    let onReminder: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 15) {
                    Image(systemName: article.symbol).font(.largeTitle).foregroundStyle(AdultPalette.category(store.category(article)?.colorKey ?? "blue"))
                        .accessibilityHidden(true)
                    Text(article.title).font(.system(.largeTitle, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Text(article.summary).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("About \(article.minutes) min · \(article.steps.count) steps").font(.subheadline).foregroundStyle(.secondary)
                    if article.jurisdiction != "General" {
                        Label(article.jurisdiction + " rules", systemImage: "globe").font(.subheadline.bold())
                    }
                }
                if !article.tools.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Before you start").font(.title2.bold())
                        ForEach(article.tools, id: \.self) { item in
                            Label(item, systemImage: "checklist").font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("One step at a time").font(.title2.bold()).padding(.bottom, 16)
                    ForEach(article.steps) { step in
                        GuideStepRow(article: article, step: step)
                        Divider()
                    }
                }
                if !article.cautions.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Good to know", systemImage: "exclamationmark.triangle").font(.title2.bold())
                        ForEach(article.cautions, id: \.self) { caution in
                            Text(caution).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(20).background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                if !article.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Go to the source").font(.title2.bold())
                        ForEach(article.sources, id: \.url) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) { Label(source.title, systemImage: "arrow.up.right.square") }
                                    .font(.body).fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 5)
                            }
                        }
                    }
                }
                Text("Reviewed \(article.updatedAt)").font(.caption).foregroundStyle(.secondary)
                if let date = store.progress(article.id).reminderDate, date > Date() {
                    VStack(alignment: .leading, spacing: 10) {
                        Label { Text(date, format: .dateTime.month().day().hour().minute()) } icon: { Image(systemName: "bell.badge") }
                        Button("Remove reminder", role: .destructive) { store.cancelReminder(article.id) }
                            .accessibilityIdentifier("remove-guide-reminder")
                    }.font(.subheadline)
                }
            }
            .padding(24).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .navigationTitle("Guide")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { store.toggleSaved(article.id) } label: {
                    Label(store.progress(article.id).isSaved ? "Unsave guide" : "Save guide", systemImage: store.progress(article.id).isSaved ? "bookmark.fill" : "bookmark")
                }.disabled(!store.canSave).accessibilityIdentifier("save-guide")
                Button(action: onReminder) { Label("Remind me", systemImage: "bell") }
                    .disabled(!store.canSave).accessibilityIdentifier("remind-guide")
                ShareLink(item: article.shareText)
            }
        }
        .accessibilityIdentifier("guide-reader")
    }
}

private struct GuideStepRow: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle
    let step: GuideStep

    var body: some View {
        let checked = store.progress(article.id).isChecked(step)
        Button { store.toggleStep(step, in: article) } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(AdultPalette.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 9) {
                    Text(step.title).font(.headline).foregroundStyle(.primary)
                    Text(step.body).font(.body).foregroundStyle(.primary)
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }.padding(.vertical, 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!store.canSave)
        .accessibilityLabel(step.title + ". " + step.body)
        .accessibilityValue(checked ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to change completion")
        .accessibilityIdentifier("step-" + step.id)
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
        .frame(minWidth: 320, idealWidth: 480, minHeight: 360)
        .onAppear {
            if let existing = store.progress(article.id).reminderDate, existing > Date() { date = existing }
            sound = store.progress(article.id).reminderSound
        }
    }
}

private struct AdultSettingsView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your library") {
                    LabeledContent("Guides", value: "\(store.articles.count)")
                    LabeledContent("Saved", value: "\(store.articles.filter { store.progress($0.id).isSaved }.count)")
                    Text("Guides and checked steps stay available offline.").font(.subheadline).foregroundStyle(.secondary)
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
                        .font(.subheadline).foregroundStyle(.secondary)
                    Link("Privacy", destination: URL(string: "https://nathanfennel.com/how-to-adult/privacy.html")!)
                    Link("Support", destination: URL(string: "https://nathanfennel.com/how-to-adult/support.html")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.frame(minWidth: 320, idealWidth: 500, minHeight: 420)
    }
}

private enum AdultPalette {
    static let accent = Color("AccentColor")
    static let ink = Color.primary
    #if os(macOS)
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
