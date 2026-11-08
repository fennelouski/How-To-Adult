import SwiftUI

/// One guide as a paged carousel: overview, one page per step, then a finish page.
/// Name and initializer are kept from the list reader so the passport review and visionOS window still open it.
struct GuideReaderView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @AppStorage(AskAIPrompt.templateKey) private var promptTemplate = ""
    @AppStorage(AskAIPrompt.includeNotesKey) private var includeNotes = false

    let article: AdultArticle
    let onReminder: () -> Void
    var isDetached = false
    var isPassportReview = false
    var initialStepID: String? = nil

    @State private var carousel: GuideCarousel
    @State private var scrolled: Int?
    @State private var editingNotes = false
    @State private var askPrompt: AskAIPresentation?
    @State private var showsSupplies = false
    @State private var markFeedback = 0
    @State private var movedForward = true
    @FocusState private var focused: Bool
    private let presenter = PresenterState.shared

    init(article: AdultArticle, onReminder: @escaping () -> Void, isDetached: Bool = false, isPassportReview: Bool = false, initialStepID: String? = nil) {
        self.article = article
        self.onReminder = onReminder
        self.isDetached = isDetached
        self.isPassportReview = isPassportReview
        self.initialStepID = initialStepID
        _carousel = State(initialValue: GuideCarousel(stepCount: article.steps.count))
    }

    private var style: CategoryStyle { store.style(article) }
    private var progress: ArticleProgress { store.progress(article.id) }
    private var currentStep: GuideStep? { carousel.stepIndex.map { article.steps[$0] } }

    var body: some View {
        VStack(spacing: 0) {
            PageIndicator(article: article, progress: progress, carousel: carousel, tint: style.tint) { go(to: $0) }
                .padding(.horizontal, 20).padding(.vertical, 10)
            pager
            actionBar
        }
        .background(AdultPalette.background)
        // The full title wraps on the overview; the bar shows the short topic name so it never truncates.
        .navigationTitle(store.category(article)?.title ?? "Guide")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.rightArrow) { arrow(forward: layoutDirection == .leftToRight) }
        .onKeyPress(.leftArrow) { arrow(forward: layoutDirection == .rightToLeft) }
        .onKeyPress(.space) {
            guard carousel.canGoForward else { return .ignored }
            go(to: carousel.index + 1)
            return .handled
        }
        .onChange(of: presenter.commandSerial) { _, _ in
            guard presenter.articleID == article.id, let command = presenter.pendingCommand else { return }
            switch command {
            case .next: go(to: carousel.index + 1)
            case .previous: go(to: carousel.index - 1)
            case .done: if let step = currentStep { mark(step, .done) }
            case .known: if let step = currentStep { mark(step, .known) }
            case .favorite: store.toggleSaved(article.id)
            }
        }
        .sensoryFeedback(.success, trigger: markFeedback)
        .sensoryFeedback(.selection, trigger: carousel.index)
        .onAppear {
            let start = initialStepID.flatMap { id in article.steps.firstIndex { $0.id == id }.map { $0 + 1 } }
                ?? GuideCarousel.resumeIndex(for: article, progress: progress)
            carousel.go(to: start)
            scrolled = carousel.index
            focused = true
            publish()
        }
        .onChange(of: scrolled) { _, index in
            if let index, index != carousel.index { carousel.go(to: index); publish() }
        }
        .onDisappear { if presenter.articleID == article.id { presenter.articleID = nil } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-reader")
        .sheet(isPresented: $editingNotes) { GuideNotesEditor(article: article) }
        .sheet(item: $askPrompt) { AskAISheet(presentation: $0) }
        .sheet(isPresented: $showsSupplies) { suppliesSheet }
    }

    /// iOS pages by swiping a horizontal scroll view. macOS shows one page with a push transition:
    /// its floating sidebar insets a horizontal scroll view and misaligns paging, and Mac navigation
    /// is keys, segments, buttons and menu commands anyway.
    @ViewBuilder private var pager: some View {
        #if os(macOS)
        ZStack {
            page(carousel.page)
                .id(carousel.index)
                .transition(reduceMotion ? .opacity : .push(from: (movedForward == (layoutDirection == .leftToRight)) ? .trailing : .leading))
        }
        .clipped()
        #else
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<carousel.pageCount, id: \.self) { index in
                    page(GuideCarousel.page(at: index, stepCount: article.steps.count))
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolled)
        .scrollIndicators(.hidden)
        // VoiceOver three-finger swipes page through steps; leading/trailing follow the layout direction.
        .accessibilityScrollAction { edge in
            switch edge {
            case .leading: go(to: carousel.index - 1)
            case .trailing: go(to: carousel.index + 1)
            default: break
            }
        }
        #endif
    }

    // MARK: Pages

    /// Short pages sit centered in the space; tall ones (large text) scroll inside the page.
    @ViewBuilder private func page(_ page: GuideCarousel.Page) -> some View {
        GeometryReader { geometry in
            ScrollView {
                Group {
                    switch page {
                    case .overview: overview
                    case .step(let index): stepPage(index)
                    case .finish: finishPage
                    }
                }
                .padding(24).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
                .frame(minHeight: page == .overview ? nil : geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                CategoryBadge(style: style, symbol: article.symbol, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Fact(symbol: "clock", text: "\(article.minutes) min", label: "About \(article.minutes) minutes")
                    Fact(symbol: "list.number", text: "\(article.steps.count)", label: "\(article.steps.count) steps")
                    if article.jurisdiction != "General" {
                        Label(article.jurisdiction + " rules", systemImage: "globe.americas.fill").font(.caption.bold())
                    }
                }
            }
            Text(article.title).font(.system(.largeTitle, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Text(article.summary).font(.title3).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
            if let notice = article.adviceNotice {
                Label(notice, systemImage: "info.circle").font(.footnote).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            if let illustration = store.illustration(for: article), let revision = store.catalog?.revision {
                GuideIllustrationView(illustration: illustration, revision: revision).id(revision)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { glanceCards }
                VStack(alignment: .leading, spacing: 12) { glanceCards }
            }
            if progress.isKnownGuide(article) {
                Label("Already known", systemImage: "checkmark.seal").font(.headline).foregroundStyle(style.tint)
            }
            Text("Reviewed \(article.updatedAt)").font(.caption).foregroundStyle(AdultPalette.secondaryText)
            if let date = progress.reminderDate, date > Date() {
                HStack {
                    Label { Text(date, format: .dateTime.month().day().hour().minute()) } icon: { Image(systemName: "bell.badge") }
                    Spacer()
                    Button("Remove reminder", role: .destructive) { store.cancelReminder(article.id) }.accessibilityIdentifier("remove-guide-reminder")
                }.font(.subheadline)
            }
        }
    }

    @ViewBuilder private var glanceCards: some View {
        if !article.tools.isEmpty {
            GlanceCard(title: "You need", symbol: "shippingbox", tint: style.tint) {
                ForEach(article.tools, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
            }.accessibilityIdentifier("card-supplies")
        }
        if !article.cautions.isEmpty {
            GlanceCard(title: "Careful", symbol: "exclamationmark.triangle.fill", tint: AdultPalette.caution) {
                ForEach(article.cautions, id: \.self) { Text($0) }
            }.accessibilityIdentifier("card-cautions")
        }
        if !article.sources.isEmpty {
            GlanceCard(title: "Sources", symbol: "link", tint: AdultPalette.accent) {
                ForEach(article.sources, id: \.url) { source in
                    if let url = URL(string: source.url) {
                        Link(destination: url) { Label(source.title, systemImage: "arrow.up.right.square") }
                    }
                }
            }.accessibilityIdentifier("card-sources")
        }
    }

    private func stepPage(_ index: Int) -> some View {
        let step = article.steps[index]
        let mark = progress.mark(step)
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                ZStack {
                    style.shape.fill(mark == nil ? AnyShapeStyle(style.ground) : AnyShapeStyle(style.tint.opacity(0.35)))
                    if let mark {
                        Image(systemName: mark == .done ? "checkmark" : "lightbulb.fill").font(.title.bold()).foregroundStyle(.white)
                    } else {
                        Text("\(index + 1)").font(.system(.title, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                .frame(width: 60, height: 60)
                .accessibilityElement()
                .accessibilityLabel("Step \(index + 1) of \(article.steps.count)")
                .accessibilityValue(mark == .done ? "Done" : mark == .known ? "Already known" : "Not done")
                Spacer()
                Button { store.toggleFavorite(step, in: article) } label: {
                    Image(systemName: progress.isFavorite(step) ? "heart.fill" : "heart").font(.title2)
                        .foregroundStyle(progress.isFavorite(step) ? Color.pink : AdultPalette.secondaryText).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).disabled(!store.canSave)
                .accessibilityLabel(progress.isFavorite(step) ? "Remove step from favorites" : "Favorite this step")
                .accessibilityIdentifier("favorite-step")
            }
            Text(step.title).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(step.body).font(.title3).fixedSize(horizontal: false, vertical: true)
                .opacity(mark == .known ? 0.6 : 1)
            if let illustration = store.illustration(for: article, stepID: step.id), let revision = store.catalog?.revision {
                GuideIllustrationView(illustration: illustration, revision: revision).id(revision)
            }
            if !article.cautions.isEmpty {
                // Safety stays next to the task on every step, in brief.
                Label { Text(article.cautions.joined(separator: " ")).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                    icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Caution: " + article.cautions.joined(separator: " "))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("step-page-" + step.id)
    }

    private var finishPage: some View {
        let open = article.steps.filter { progress.mark($0) == nil }
        return VStack(spacing: 22) {
            ZStack {
                style.shape.fill(open.isEmpty ? AnyShapeStyle(style.ground) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                Image(systemName: open.isEmpty ? "checkmark.seal.fill" : article.symbol).font(.system(size: 64, weight: .bold))
                    .foregroundStyle(open.isEmpty ? Color.white : Color.secondary)
                    .symbolEffect(.bounce, value: open.isEmpty)
            }
            .frame(width: 160, height: 160)
            .scaleEffect(open.isEmpty || reduceMotion ? 1 : 0.9)
            .animation(.adult(reduceMotion), value: open.isEmpty)
            .accessibilityElement()
            .accessibilityLabel(open.isEmpty ? "Guide finished. Stamp added to your passport." : "\(open.count) steps left")
            .accessibilityIdentifier("finish-stamp")
            StepSegments(article: article, progress: progress, tint: style.tint, height: 10).frame(maxWidth: 320)
            if let first = open.first, let index = article.steps.firstIndex(of: first) {
                Button { go(to: index + 1) } label: { Label("\(open.count)", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityLabel("Go to the first of \(open.count) open steps")
            }
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { stars in
                    let selected = progress.rating ?? 0
                    Button { store.rate(article.id, stars: selected == stars ? nil : stars) } label: {
                        Image(systemName: selected >= stars ? "star.fill" : "star").font(.title2)
                            .foregroundStyle(selected >= stars ? Color.yellow : AdultPalette.secondaryText).frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain).disabled(!store.canSave)
                    .accessibilityLabel("Rate \(stars) out of 5").accessibilityValue(selected == stars ? "Selected" : "Not selected")
                }
            }
            Button { editingNotes = true } label: {
                Label(progress.personalNotes == nil ? "Add notes" : "Notes", systemImage: "square.and.pencil").font(.headline)
            }.disabled(!store.canSave).accessibilityIdentifier("guide-personal-notes")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    @ViewBuilder private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                switch carousel.page {
                case .overview:
                    HStack(spacing: 12) { overviewActions }.iconOnly(typeSize.isAccessibilitySize)
                case .step(let index):
                    let step = article.steps[index]
                    // At accessibility sizes the bar keeps one compact row of icons so the step itself keeps the screen.
                    HStack(spacing: 12) { stepActions(step) }.iconOnly(typeSize.isAccessibilitySize)
                case .finish:
                    Button { go(to: 0) } label: { Label("Overview", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).controlSize(.large)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(.bar)
    }

    @ViewBuilder private var overviewActions: some View {
        Button { store.setGuideKnown(true, article) } label: {
            Label(progress.isKnownGuide(article) ? "Known" : "I know this", systemImage: progress.isKnownGuide(article) ? "lightbulb.fill" : "lightbulb")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).controlSize(.large).disabled(!store.canSave || progress.isKnownGuide(article))
        .accessibilityIdentifier("know-guide")
        Button { go(to: GuideCarousel.resumeIndex(for: article, progress: progress).clamped(min: 1)) } label: {
            Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).controlSize(.large).tint(style.ground)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("start-guide")
    }

    @ViewBuilder private func stepActions(_ step: GuideStep) -> some View {
        let mark = progress.mark(step)
        Button { mark == .known ? unmark(step) : self.mark(step, .known) } label: {
            Label(mark == .known ? "Known" : "I know this", systemImage: mark == .known ? "lightbulb.fill" : "lightbulb").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).controlSize(.large).disabled(!store.canSave)
        .accessibilityHint(mark == .known ? "Undo" : "Counts toward progress and moves on")
        .accessibilityIdentifier("know-step")
        Button { mark == .done ? unmark(step) : self.mark(step, .done) } label: {
            Label("Done", systemImage: mark == .done ? "checkmark.circle.fill" : "checkmark.circle").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).controlSize(.large).tint(style.ground).disabled(!store.canSave)
        .accessibilityValue(mark == .done ? "Completed" : "Not completed")
        .accessibilityHint(mark == .done ? "Undo" : "Moves to the next step")
        .accessibilityIdentifier("done-step")
        Button { go(to: carousel.index + 1) } label: {
            Label { Text("Skip") } icon: { Image(systemName: "forward.fill").flipsForRightToLeftLayoutDirection(true) }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).controlSize(.large)
        .accessibilityIdentifier("skip-step")
    }

    private func mark(_ step: GuideStep, _ mark: StepMark) {
        guard store.setMark(mark, for: step, in: article) else { return }
        markFeedback += 1
        let index = carousel.index
        // A brief pause lets the mark register before moving on; Reduce Motion moves without animation.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if carousel.index == index { go(to: index + 1) }
        }
    }

    private func unmark(_ step: GuideStep) { store.setMark(nil, for: step, in: article) }

    private func go(to index: Int) {
        movedForward = index >= carousel.index
        withAnimation(.adult(reduceMotion)) {
            carousel.go(to: index)
            scrolled = carousel.index
        }
        publish()
    }

    private func arrow(forward: Bool) -> KeyPress.Result {
        go(to: carousel.index + (forward ? 1 : -1))
        return .handled
    }

    private func publish() {
        presenter.articleID = article.id
        presenter.pageIndex = carousel.index
    }

    // MARK: Toolbar and overflow

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        #if os(visionOS)
        if !isDetached { ToolbarItemGroup(placement: .automatic) { toolbarButtons } }
        #else
        ToolbarItemGroup(placement: .automatic) { toolbarButtons }
        #endif
    }

    @ViewBuilder private var toolbarButtons: some View {
        Button { showsSupplies = true } label: { Label("What you need", systemImage: "shippingbox") }
            .disabled(article.tools.isEmpty && article.cautions.isEmpty)
            .accessibilityIdentifier("show-supplies")
        Button { store.toggleSaved(article.id) } label: {
            Label(progress.isSaved ? "Remove from favorites" : "Favorite", systemImage: progress.isSaved ? "heart.fill" : "heart")
        }
        .disabled(!store.canSave).accessibilityIdentifier("save-guide")
        overflowMenu
    }

    private var overflowMenu: some View {
        Menu {
            Section {
                Button { store.toggleSaved(article.id) } label: {
                    Label(progress.isSaved ? "Remove from favorites" : "Favorite guide", systemImage: progress.isSaved ? "heart.slash" : "heart")
                }
                if let step = currentStep {
                    Button { store.toggleFavorite(step, in: article) } label: {
                        Label(progress.isFavorite(step) ? "Unfavorite step" : "Favorite step", systemImage: progress.isFavorite(step) ? "heart.slash" : "heart.text.square")
                    }
                    Button { progress.isKnown(step) ? unmark(step) : mark(step, .known) } label: {
                        Label(progress.isKnown(step) ? "Step: not known" : "Step: I know this", systemImage: "lightbulb")
                    }
                }
                Button { store.setGuideKnown(!progress.isKnownGuide(article), article) } label: {
                    Label(progress.isKnownGuide(article) ? "Guide: not known" : "Guide: I know this", systemImage: "lightbulb.max")
                }.accessibilityIdentifier("menu-know-guide")
            }
            Section {
                Button { askAI() } label: { Label("Ask an AI", systemImage: "bubble.left.and.text.bubble.right") }
                    .accessibilityIdentifier("menu-ask-ai")
                Button {
                    if let url = WebSearch.googleURL(WebSearch.query(article: article, stepIndex: carousel.stepIndex)) { openURL(url) }
                } label: { Label("Search Google", systemImage: "magnifyingglass") }
                    .accessibilityIdentifier("menu-search-google")
            }
            Section {
                ShareLink(item: article.shareText) { Label("Share", systemImage: "square.and.arrow.up") }
                if !isPassportReview {
                    Button(action: onReminder) { Label("Remind me", systemImage: "bell") }.disabled(!store.canSave)
                        .accessibilityIdentifier("remind-guide")
                }
                Button { editingNotes = true } label: { Label("Notes", systemImage: "square.and.pencil") }.disabled(!store.canSave)
                if !isPassportReview {
                    Button {
                        assistant.prepare(article)
                        #if os(visionOS)
                        openWindow(id: "assistant")
                        #endif
                    } label: { Label("Help me do this", systemImage: "sparkles") }
                        .accessibilityIdentifier("guide-assistant")
                }
            }
            presenterSection
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("guide-more")
    }

    @ViewBuilder private var presenterSection: some View {
        #if os(macOS)
        Section {
            Button { openWindow(id: "presenter") } label: { Label("Show presenter window", systemImage: "rectangle.on.rectangle") }
        }
        #elseif os(iOS)
        if presenter.externalDisplayConnected {
            Section("Second screen") {
                Picker("Second screen", selection: Binding(get: { presenter.mode }, set: { presenter.mode = $0 })) {
                    ForEach(PresenterMode.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
        }
        #endif
    }

    private func askAI() {
        let prompt = AskAIPrompt.make(template: promptTemplate, article: article, stepIndex: carousel.stepIndex, progress: progress, includeNotes: includeNotes)
        Clipboard.copy(prompt)
        askPrompt = AskAIPresentation(prompt: prompt)
    }

    private var suppliesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { glanceCards }.padding(20)
            }
            .navigationTitle(article.title)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsSupplies = false } } }
        }
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 320)
        #endif
    }
}

extension View {
    @ViewBuilder func iconOnly(_ enabled: Bool) -> some View {
        if enabled { labelStyle(.iconOnly) } else { self }
    }
}

private extension Int {
    func clamped(min lower: Int) -> Int { Swift.max(self, lower) }
}

/// Tappable segments: overview dot, one segment per step, finish dot.
struct PageIndicator: View {
    let article: AdultArticle
    let progress: ArticleProgress
    let carousel: GuideCarousel
    let tint: Color
    let go: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            dot(index: 0, symbol: "info.circle", label: "Overview")
            ForEach(Array(article.steps.enumerated()), id: \.offset) { i, step in
                let mark = progress.mark(step)
                Button { go(i + 1) } label: {
                    Capsule()
                        .fill(mark == .done ? AnyShapeStyle(tint) : mark == .known ? AnyShapeStyle(tint.opacity(0.4)) : AnyShapeStyle(Color.secondary.opacity(0.2)))
                        .frame(height: carousel.index == i + 1 ? 10 : 6)
                        .overlay { if carousel.index == i + 1 { Capsule().strokeBorder(Color.primary, lineWidth: 1.5) } }
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(i + 1)")
                .accessibilityValue((mark == .done ? "Done" : mark == .known ? "Already known" : "Open") + (carousel.index == i + 1 ? ", current" : ""))
            }
            dot(index: carousel.pageCount - 1, symbol: "flag.checkered", label: "Finish")
        }
        .animation(.snappy, value: carousel.index)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page-indicator")
    }

    private func dot(index: Int, symbol: String, label: String) -> some View {
        Button { go(index) } label: {
            Image(systemName: symbol).font(.subheadline.weight(carousel.index == index ? .bold : .regular))
                .foregroundStyle(carousel.index == index ? tint : Color.secondary)
                .frame(minWidth: 32, minHeight: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(carousel.index == index ? "Current" : "")
    }
}

struct GlanceCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(tint).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) { content }.font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 6)).accessibilityHidden(true)
            configuration.title
        }
    }
}

// MARK: Keyboard and menu commands

/// Menu-bar and keyboard-shortcut commands. They post to PresenterState, which the visible guide observes.
/// (A closure-carrying focusedSceneValue caused an update loop during accessibility snapshots.)
struct GuideMenuCommands: Commands {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    private let presenter = PresenterState.shared
    var body: some Commands {
        CommandMenu("Guide") {
            let disabled = presenter.articleID == nil
            Button("Next Step") { presenter.send(.next) }.keyboardShortcut(.rightArrow, modifiers: .command).disabled(disabled)
            Button("Previous Step") { presenter.send(.previous) }.keyboardShortcut(.leftArrow, modifiers: .command).disabled(disabled)
            Divider()
            Button("Mark Step Done") { presenter.send(.done) }.keyboardShortcut(.return, modifiers: .command).disabled(disabled)
            Button("I Know This Step") { presenter.send(.known) }.keyboardShortcut("k", modifiers: [.command, .shift]).disabled(disabled)
            Button("Favorite Guide") { presenter.send(.favorite) }.keyboardShortcut("d", modifiers: .command).disabled(disabled)
            #if os(macOS)
            Divider()
            Button("Show Presenter Window") { openWindow(id: "presenter") }.keyboardShortcut("p", modifiers: [.command, .shift])
            #endif
        }
    }
}

// MARK: Ask an AI

struct AskAIPresentation: Identifiable {
    let id = UUID()
    let prompt: String
}

enum Clipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

/// Confirms the copy and offers the assistant chosen in Settings. Nothing is sent from the app.
struct AskAISheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AskAIPrompt.destinationKey) private var destination = AIDestination.chatgpt
    let presentation: AskAIPresentation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Copied", systemImage: "doc.on.clipboard.fill").font(.title2.bold()).foregroundStyle(.green)
                        .accessibilityIdentifier("ask-ai-copied")
                    Text(presentation.prompt).font(.callout.monospaced()).textSelection(.enabled)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Picker("Paste into", selection: $destination) {
                        ForEach(AIDestination.allCases) { Text($0.title).tag($0) }
                    }
                    if let url = destination.url {
                        Button { openURL(url); dismiss() } label: {
                            Label("Open \(destination.title) and paste", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("ask-ai-open")
                    }
                    Button { Clipboard.copy(presentation.prompt) } label: { Label("Copy again", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                .padding(20)
            }
            .navigationTitle("Ask an AI")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 440)
        #endif
    }
}

struct AskAISettingsSection: View {
    @AppStorage(AskAIPrompt.destinationKey) private var destination = AIDestination.chatgpt
    @AppStorage(AskAIPrompt.includeNotesKey) private var includeNotes = false
    var body: some View {
        Section("Ask an AI") {
            Picker("Paste into", selection: $destination) {
                ForEach(AIDestination.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Include my notes", isOn: $includeNotes)
            NavigationLink { PromptTemplateEditor() } label: { Label("Prompt template", systemImage: "text.badge.star") }
        }
    }
}

struct PromptTemplateEditor: View {
    @AppStorage(AskAIPrompt.templateKey) private var template = ""
    @State private var draft = ""
    var body: some View {
        Form {
            Section {
                TextEditor(text: $draft).font(.callout.monospaced()).frame(minHeight: 220)
                    .accessibilityLabel("Prompt template")
            } footer: {
                Text(AskAIPrompt.placeholders.map { "{\($0)}" }.joined(separator: "  ")).textSelection(.enabled)
            }
            Section {
                Button("Save") { template = draft == AskAIPrompt.defaultTemplate ? "" : draft }.disabled(draft == (template.isEmpty ? AskAIPrompt.defaultTemplate : template))
                Button("Restore default", role: .destructive) { template = ""; draft = AskAIPrompt.defaultTemplate }.disabled(template.isEmpty)
            }
        }
        .navigationTitle("Prompt template")
        .onAppear { draft = template.isEmpty ? AskAIPrompt.defaultTemplate : template }
    }
}
