import SwiftUI

enum AdultRoute: Hashable {
    case guide(String)
    case step(guideID: String, stepID: String)
    case category(String)
}

/// Routes a guide or category tap: a push in stacks, the same push in the split-view detail stack.
struct RouteLink<Label: View>: View {
    let route: AdultRoute
    @ViewBuilder let label: Label
    var body: some View { NavigationLink(value: route) { label }.buttonStyle(.plain) }
}

// MARK: Now

struct NowView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let openExplore: () -> Void

    private var favorites: [AdultArticle] { store.articles.filter { store.progress($0.id).isSaved } }
    private var favoriteSteps: [(AdultArticle, GuideStep)] {
        store.articles.flatMap { article in article.steps.filter { store.progress(article.id).isFavorite($0) }.map { (article, $0) } }
    }
    private var suggestions: [AdultArticle] {
        Array(store.articles.filter { !store.progress($0.id).isFinished($0) && $0.minutes <= GuideFilter.quickMinutes }.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AdultPrivateQABanner()
                StorageIssueBanner()
                if store.inProgress.isEmpty {
                    shelf("Start something", symbol: "play.circle") {
                        LazyVGrid(columns: AdaptiveColumns.guides(typeSize), spacing: 12) {
                            ForEach(suggestions) { article in RouteLink(route: .guide(article.id)) { GuideCard(article: article) } }
                        }
                        Button(action: openExplore) { Label("Explore all guides", systemImage: "square.grid.2x2").font(.headline) }
                            .buttonStyle(.bordered).accessibilityIdentifier("now-explore")
                    }
                } else {
                    shelf("Continue", symbol: "play.circle") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 600 : 320), spacing: 14)], spacing: 14) {
                            ForEach(store.inProgress) { article in RouteLink(route: .guide(article.id)) { ContinueCard(article: article) } }
                        }
                    }
                }
                if !store.upcoming.isEmpty {
                    shelf("Upcoming", symbol: "bell") {
                        ForEach(store.upcoming) { article in
                            RouteLink(route: .guide(article.id)) {
                                HStack(spacing: 12) {
                                    CategoryBadge(style: store.style(article), symbol: article.symbol, size: 36)
                                    Text(article.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    if let date = store.progress(article.id).reminderDate {
                                        Label { Text(date, format: .dateTime.month(.abbreviated).day().hour().minute()) } icon: { Image(systemName: "bell.fill") }
                                            .font(.subheadline.weight(.semibold)).foregroundStyle(AdultPalette.accent)
                                    }
                                }
                                .padding(12).background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                if !favorites.isEmpty || !favoriteSteps.isEmpty {
                    shelf("Favorites", symbol: "heart") {
                        LazyVGrid(columns: AdaptiveColumns.guides(typeSize), spacing: 12) {
                            ForEach(favorites) { article in RouteLink(route: .guide(article.id)) { GuideCard(article: article) } }
                        }
                        ForEach(favoriteSteps, id: \.1.id) { article, step in
                            RouteLink(route: .step(guideID: article.id, stepID: step.id)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.title).font(.headline)
                                        Text(article.title).font(.caption).foregroundStyle(AdultPalette.secondaryText)
                                    }.fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(12).background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("favorite-step-" + step.id)
                            }
                        }
                    }
                }
            }
            .padding(20).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .navigationTitle("Now")
        .accessibilityIdentifier("now-screen")
    }

    private func shelf<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// A large colored card for a guide in progress, showing the next step.
struct ContinueCard: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle

    var body: some View {
        let style = store.style(article)
        let progress = store.progress(article.id)
        let next = article.steps.first { progress.mark($0) == nil }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: article.symbol).font(.system(size: 34, weight: .semibold)).accessibilityHidden(true)
                Spacer()
                Image(systemName: "play.fill").font(.title3).padding(12).background(.white.opacity(0.22), in: Circle()).accessibilityHidden(true)
            }
            Text(article.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            if let next {
                Label { Text(next.title) } icon: { Image(systemName: "arrow.turn.down.right").flipsForRightToLeftLayoutDirection(true) }
                    .font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            StepSegments(article: article, progress: progress, tint: .white, height: 8)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ZStack { style.ground; MotifPattern(motif: style.motif) } }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Continues the guide")
        .accessibilityIdentifier("continue-" + article.id)
    }
}

// MARK: Explore

struct ExploreView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var filter: GuideFilter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StorageIssueBanner()
                FilterBar(filter: $filter)
                if filter.isActive {
                    let results = filter.apply(store.articles, progress: store.progress)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: filter.query)
                    } else {
                        LazyVGrid(columns: AdaptiveColumns.guides(typeSize), spacing: 12) {
                            ForEach(results) { article in RouteLink(route: .guide(article.id)) { GuideCard(article: article) } }
                        }
                    }
                } else {
                    CategoryBento()
                }
            }
            .padding(20).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .navigationTitle("Explore")
        .searchable(text: $filter.query, prompt: Text("Search guides"))
        .refreshable { await store.refresh() }
        .accessibilityIdentifier("guide-collection")
    }
}

struct FilterBar: View {
    @Binding var filter: GuideFilter
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "Favorites", symbol: "heart", isOn: $filter.favoritesOnly).accessibilityIdentifier("filter-favorites")
                FilterChip(title: "Hide known", symbol: "eye.slash", isOn: $filter.hideKnown).accessibilityIdentifier("filter-known")
                FilterChip(title: "≤ \(GuideFilter.quickMinutes) min", symbol: "clock", isOn: $filter.quickOnly).accessibilityIdentifier("filter-quick")
                    .accessibilityLabel("\(GuideFilter.quickMinutes) minutes or less")
                Menu {
                    Picker("Region", selection: $filter.region) {
                        Label("All regions", systemImage: "globe").tag(GuideFilter.Region.any)
                        Label("Everywhere", systemImage: "globe").tag(GuideFilter.Region.general)
                        Label("United States", systemImage: "globe.americas").tag(GuideFilter.Region.unitedStates)
                    }
                } label: {
                    Label(filter.region == .unitedStates ? "US" : filter.region == .general ? "Everywhere" : "Region",
                          systemImage: filter.region == .unitedStates ? "globe.americas.fill" : "globe")
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(filter.region == .any ? Color.primary : Color.white)
                        .background(filter.region == .any ? AnyShapeStyle(AdultPalette.surface) : AnyShapeStyle(AdultPalette.accent), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter-region")
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// Seven colored tiles. The last tile of an uneven row spans the row.
struct CategoryBento: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var columns: Int {
        if typeSize.isAccessibilitySize { return 1 }
        #if os(iOS)
        return sizeClass == .regular ? 3 : 2
        #else
        return 3
        #endif
    }

    var body: some View {
        let categories = store.categories
        let rows = stride(from: 0, to: categories.count, by: columns).map { Array(categories[$0..<min($0 + columns, categories.count)]) }
        VStack(spacing: 12) {
            ForEach(rows, id: \.first?.id) { row in
                HStack(spacing: 12) {
                    ForEach(row) { category in
                        RouteLink(route: .category(category.id)) { CategoryTile(category: category, wide: row.count < columns) }
                    }
                }
            }
        }
    }
}

struct CategoryTile: View {
    @Environment(AdultStore.self) private var store
    let category: GuideCategory
    var wide = false

    var body: some View {
        let style = CategoryStyle.of(category.id, colorKey: category.colorKey)
        let guides = store.articles.filter { $0.categoryID == category.id }
        let finished = guides.filter { store.progress($0.id).isFinished($0) }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: category.symbol).font(.system(size: wide ? 38 : 32, weight: .semibold)).accessibilityHidden(true)
                Spacer()
                ProgressRing(fraction: guides.isEmpty ? 0 : Double(finished) / Double(guides.count)).frame(width: 30, height: 30)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 8)
            Text(category.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack").accessibilityHidden(true)
                Text("\(guides.count)")
            }.font(.subheadline.weight(.semibold)).opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background { ZStack { style.ground; MotifPattern(motif: style.motif) } }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        #if os(iOS) || os(visionOS)
        .hoverEffect(.lift)
        #endif
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.title)
        .accessibilityValue("\(guides.count) guides, \(finished) finished")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("category-" + category.id)
    }
}

struct CategoryView: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let category: GuideCategory
    @State private var area: GuideSubArea?
    @State private var filter = GuideFilter()

    var body: some View {
        let style = CategoryStyle.of(category.id, colorKey: category.colorKey)
        let guides = filter.apply(store.articles.filter { $0.categoryID == category.id }, progress: store.progress)
            .filter { area?.contains($0) ?? true }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    CategoryBadge(style: style, symbol: category.symbol, size: 56)
                    Text(category.title).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(GuideSubArea.available(for: category.id, in: store.articles)) { item in
                            FilterChip(title: item.title, symbol: item.symbol, isOn: Binding(get: { area == item }, set: { area = $0 ? item : nil }))
                                .accessibilityIdentifier("subarea-" + item.id)
                        }
                    }
                }.scrollIndicators(.hidden)
                FilterBar(filter: $filter)
                if guides.isEmpty {
                    ContentUnavailableView("Nothing matches", systemImage: "line.3.horizontal.decrease.circle")
                } else {
                    LazyVGrid(columns: AdaptiveColumns.guides(typeSize), spacing: 12) {
                        ForEach(guides) { article in RouteLink(route: .guide(article.id)) { GuideCard(article: article) } }
                    }
                }
            }
            .padding(20).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(alignment: .top) { style.ground.opacity(0.12).frame(height: 220).ignoresSafeArea() }
        .background(AdultPalette.background)
        .navigationTitle(category.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .tint(style.tint)
    }
}

// MARK: Passport

struct PassportStampsView: View {
    @Environment(AdultStore.self) private var store
    @Environment(AdultPassportStore.self) private var skills: AdultPassportStore?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let topics = TopicStamps.make(categories: store.categories, articles: store.articles, progress: store.progress)
        let earned = topics.reduce(0) { $0 + $1.earned }
        let total = topics.reduce(0) { $0 + $1.guides.count }
        let earnedSkills = skills?.achievements.filter { $0.status == .earned && $0.visibleOnSash } ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    ZStack {
                        ProgressRing(fraction: total == 0 ? 0 : Double(earned) / Double(total), lineWidth: 10, color: AdultPalette.accent)
                        VStack(spacing: 0) {
                            Text("\(earned)").font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Image(systemName: "seal.fill").foregroundStyle(AdultPalette.accent)
                        }
                    }
                    .frame(width: 110, height: 110)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Stamps")
                    .accessibilityValue("\(earned) of \(total) guides finished")
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(topics.filter(\.isComplete).count) of \(topics.count)", systemImage: "rosette")
                            .font(.title3.bold()).accessibilityLabel("\(topics.filter(\.isComplete).count) of \(topics.count) topics complete")
                        Label("\(earnedSkills.count)", systemImage: "checkmark.seal.fill")
                            .font(.title3.bold()).accessibilityLabel("\(earnedSkills.count) reviewed skills")
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 600 : 320), spacing: 14, alignment: .top)], spacing: 14) {
                    ForEach(topics) { topic in PassportPage(topic: topic) }
                }
                if !earnedSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Skills", systemImage: "checkmark.seal.fill").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        ForEach(earnedSkills) { achievement in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.yellow).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(achievement.entry.outcome).font(.headline)
                                    Text(achievement.confidence.title).font(.caption).foregroundStyle(AdultPalette.secondaryText)
                                }.fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(20).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .navigationTitle("Passport")
        .accessibilityIdentifier("passport-screen")
    }
}

/// One passport page per topic. Finished guides are stamped; a finished topic gets a full-page visa seal.
struct PassportPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let topic: TopicStamps

    var body: some View {
        let style = CategoryStyle.of(topic.category.id, colorKey: topic.category.colorKey)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(topic.category.title, systemImage: topic.category.symbol).font(.headline).foregroundStyle(style.tint)
                Spacer()
                Text("\(topic.earned)/\(topic.guides.count)").font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AdultPalette.secondaryText)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                ForEach(topic.guides, id: \.article.id) { item in
                    RouteLink(route: .guide(item.article.id)) { stamp(item.article, item.stamp, style) }
                }
            }
        }
        .padding(16)
        .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if topic.isComplete {
                ZStack {
                    Circle().fill(style.ground)
                    Circle().strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 3])).padding(5)
                    Image(systemName: topic.category.symbol).font(.title2.bold()).foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(reduceMotion ? 0 : -12))
                .offset(x: 10, y: -14)
                .accessibilityElement()
                .accessibilityLabel(topic.category.title + " complete")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport-page-" + topic.category.id)
    }

    private func stamp(_ article: AdultArticle, _ kind: TopicStamps.Stamp, _ style: CategoryStyle) -> some View {
        ZStack {
            switch kind {
            case .done: style.shape.fill(style.ground)
            case .known: style.shape.stroke(style.tint, lineWidth: 2.5)
            case .open: style.shape.stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            Image(systemName: kind == .known ? "checkmark" : article.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(kind == .done ? Color.white : kind == .known ? style.tint : Color.secondary.opacity(0.5))
        }
        .frame(width: 52, height: 52)
        .accessibilityElement()
        .accessibilityLabel(article.title)
        .accessibilityValue(kind == .done ? "Finished" : kind == .known ? "Already known" : "Not yet")
    }
}

struct StorageIssueBanner: View {
    @Environment(AdultStore.self) private var store
    var body: some View {
        if let issue = store.storageIssue {
            VStack(alignment: .leading, spacing: 10) {
                Label("Saved guides need attention", systemImage: "exclamationmark.triangle").font(.headline)
                Text(issue).font(.subheadline)
                Button("Retry opening saved guides") { Task { store.reloadLocalFiles(); await store.activateNotifications() } }
            }
            .padding().background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
