#if DEBUG
import SwiftUI

struct AdultPassportReviewRoot: View {
    @Environment(AdultPassportStore.self) private var passport
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "wrench.and.screwdriver").accessibilityHidden(true)
                Text("Review preview · local test data and placeholder badges")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }.padding(8).frame(maxWidth: .infinity).background(.bar)
            TabView(selection: $section) {
            NavigationStack {
                PassportExploreView()
                    .navigationDestination(for: PassportWorld.self) { PassportWorldView(world: $0) }
                    .navigationDestination(for: PassportEntry.self) { PassportGuideView(entry: $0, showSash: { section = 2 }) }
            }.tabItem { Label("Explore", systemImage: "map") }.tag(0)
            NavigationStack { PassportPocketGuideView() }
                .tabItem { Label("Pocket guide", systemImage: "book.pages") }.tag(1)
            NavigationStack { PassportCollectionView() }
                .tabItem { Label("My sash", systemImage: "seal") }.tag(2)
            }
        }
        .tint(AdultPalette.accent)
        .alert("Passport change not saved", isPresented: Binding(get: { passport.actionIssue != nil }, set: { if !$0 { passport.actionIssue = nil } })) {
            Button("OK", role: .cancel) { passport.actionIssue = nil }
        } message: { Text(passport.actionIssue ?? "") }
    }
}

private struct PassportExploreView: View {
    @Environment(AdultPassportStore.self) private var passport
    @Environment(AdultStore.self) private var guides
    @State private var query = ""
    @State private var showsMap = true

    private var entries: [PassportEntry] {
        passport.admittedEntries().filter { passport.article(for: $0)?.matches(query) == true }
    }
    private var worlds: [PassportWorld] {
        passport.worlds().filter { world in entries.contains { $0.worldIDs.contains(world.id) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PassportHeading(eyebrow: "YOUR OWN PACE", title: "A little more capable.", subtitle: "Choose a place to begin. Every world is open.")
                TextField("Find a skill", text: $query).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("passport-search")
                Picker("Discovery view", selection: $showsMap) {
                    Text("Map").tag(true)
                    Text("List").tag(false)
                }.pickerStyle(.segmented)
                if let entry = entries.first(where: { entry in
                    passport.activity(for: entry.guideID) == .trying && !passport.achievements.contains { $0.canonicalBadgeID == entry.canonicalBadgeID && $0.status == .earned }
                }) {
                    NavigationLink(value: entry) {
                        Label("Continue your task", systemImage: "arrow.turn.down.right")
                            .font(.headline).padding(.vertical, 10)
                    }.accessibilityIdentifier("passport-continue")
                }
                if showsMap, !worlds.isEmpty {
                    VStack(spacing: 20) {
                        ForEach(worlds) { world in
                            NavigationLink(value: world) {
                                HStack(spacing: 16) {
                                    Image(systemName: world.symbol).font(.largeTitle).frame(width: 64, height: 64)
                                        .background(.background, in: UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 18, bottomTrailingRadius: 30, topTrailingRadius: 22))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(world.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                                        Text(world.id == "home-base" ? "Make room for everyday life" : "Notice, understand, take care")
                                            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                        Text("\(entries.filter { $0.worldIDs.contains(world.id) }.count) available task")
                                            .font(.caption)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").accessibilityHidden(true)
                                }.foregroundStyle(.primary).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AdultPalette.category(world.colorKey).opacity(0.16), in: RoundedRectangle(cornerRadius: 26))
                            }.buttonStyle(.plain)
                        }
                    }.padding(16).background(AdultPalette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 32))
                    Text("Diagram preview · scene artwork is awaiting verified files")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVStack(spacing: 0) { ForEach(entries) { entry in PassportEntryLink(entry: entry) } }
                }
                if entries.isEmpty { ContentUnavailableView.search(text: query) }
                if entries.contains(where: { guides.progress($0.guideID).isSaved }) {
                    Text("Saved for later").font(.title2.bold())
                    LazyVStack(spacing: 0) {
                        ForEach(entries.filter { guides.progress($0.guideID).isSaved }) { PassportEntryLink(entry: $0) }
                    }
                }
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }.navigationTitle("Explore")
    }
}

private struct PassportWorldView: View {
    @Environment(AdultPassportStore.self) private var passport
    @Environment(AdultStore.self) private var guides
    let world: PassportWorld
    @State private var savedOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: world.symbol).font(.largeTitle).foregroundStyle(AdultPalette.category(world.colorKey)).accessibilityHidden(true)
                PassportHeading(eyebrow: "AN OPEN WORLD", title: world.title, subtitle: "One useful thing at a time.")
                Toggle("Saved guides only", isOn: $savedOnly)
                LazyVStack(spacing: 0) {
                    ForEach(passport.admittedEntries().filter { $0.worldIDs.contains(world.id) && (!savedOnly || guides.progress($0.guideID).isSaved) }) {
                        PassportEntryLink(entry: $0)
                    }
                }
                if savedOnly && !passport.admittedEntries().contains(where: { $0.worldIDs.contains(world.id) && guides.progress($0.guideID).isSaved }) {
                    ContentUnavailableView("Nothing saved here yet", systemImage: "bookmark", description: Text("Turn off the filter to explore."))
                }
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }.navigationTitle("World")
    }
}

private struct PassportEntryLink: View {
    @Environment(AdultPassportStore.self) private var passport
    @Environment(AdultStore.self) private var guides
    let entry: PassportEntry

    var body: some View {
        if let article = passport.article(for: entry) {
            NavigationLink(value: entry) {
                HStack(alignment: .top, spacing: 16) {
                    PassportBadgeMark(symbol: article.symbol, kind: entry.badgeKind).frame(width: 56, height: 64).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(article.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text(article.summary).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if guides.progress(article.id).isSaved { Label("Saved", systemImage: "bookmark.fill").font(.caption) }
                        if let activity = passport.activity(for: article.id) { Text(activity == .trying ? "Trying" : "Learning").font(.caption.bold()) }
                        if passport.achievements.contains(where: { $0.canonicalBadgeID == entry.canonicalBadgeID && $0.status == .earned }) {
                            Label("Self-reported", systemImage: "checkmark.circle").font(.caption)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).padding(.top, 6).accessibilityHidden(true)
                }.padding(.vertical, 18).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Divider()
        }
    }
}

private struct PassportGuideView: View {
    @Environment(AdultPassportStore.self) private var passport
    let entry: PassportEntry
    let showSash: () -> Void
    @State private var showsTask = false

    var body: some View {
        Group {
            if let article = passport.article(for: entry) {
                GuideReaderView(article: article, onReminder: {}, isPassportReview: true)
                    .safeAreaInset(edge: .bottom) {
                        Button {
                            if passport.setActivity(.trying, for: entry.guideID) { showsTask = true }
                        } label: { Label("Try this", systemImage: "arrow.right.circle").font(.headline).padding(10).frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).disabled(!passport.canSave)
                            .padding(12).background(.bar).accessibilityIdentifier("passport-try-task")
                    }
                    .task { if passport.activity(for: entry.guideID) == nil { passport.setActivity(.learning, for: entry.guideID) } }
            } else { ContentUnavailableView("This task is unavailable", systemImage: "book.closed") }
        }
        .sheet(isPresented: $showsTask) { NavigationStack { PassportTaskView(entry: entry, showSash: showSash) } }
    }
}

private struct PassportTaskView: View {
    @Environment(AdultPassportStore.self) private var passport
    @Environment(\.dismiss) private var dismiss
    let entry: PassportEntry
    let showSash: () -> Void
    @State private var date = Date()
    @State private var showsReport = false
    @State private var earned = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PassportHeading(eyebrow: entry.badgeKind == .prepared ? "PREPARED, NOT CERTIFIED" : "A SMALL REAL-LIFE ATTEMPT",
                    title: earned ? "That’s one for your sash." : (showsReport ? "How did it go?" : "One small attempt."),
                    subtitle: earned ? "Self-reported achievement" : "You choose what feels useful. You can stop at any time.")
                if earned {
                    PassportBadgeMark(symbol: "tag", kind: entry.badgeKind).frame(width: 120, height: 136).frame(maxWidth: .infinity).accessibilityHidden(true)
                    Text(entry.outcome).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                    Button("See my sash") { dismiss(); showSash() }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                    Text("You can hide it, change your confidence or undo it in My sash.")
                        .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else if showsReport {
                    Text(entry.criterion).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When I tried it").fixedSize(horizontal: false, vertical: true)
                        DatePicker("When I tried it", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                    }
                    Button {
                        if passport.award(entry, on: date, confidence: .canDo) { earned = true }
                    } label: { Label("I can do this", systemImage: "checkmark.seal").font(.headline).padding(10).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).disabled(!passport.canSave).accessibilityIdentifier("passport-self-report")
                    Button("Still practicing") {
                        if let previous = passport.achievements.first(where: { $0.canonicalBadgeID == entry.canonicalBadgeID && $0.status == .earned }) {
                            if passport.setConfidence(.practicing, for: previous.canonicalBadgeID) { dismiss() }
                        } else if passport.setActivity(.trying, for: entry.guideID) { dismiss() }
                    }.buttonStyle(.bordered).frame(minHeight: 44)
                    Button("Not for me") { if passport.setActivity(nil, for: entry.guideID) { dismiss() } }
                        .frame(minHeight: 44)
                } else {
                    Text(entry.task).font(.title3).fixedSize(horizontal: false, vertical: true)
                    Label("Stop & check", systemImage: "hand.raised").font(.headline)
                    ForEach(entry.warnings, id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
                    Text("A badge records your own report of this bounded task. Reading or checking guide steps does not earn it.")
                        .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { showsReport = true } label: {
                        Label("I’ve tried this task", systemImage: "arrow.right").font(.headline).padding(10).frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("passport-tried-task")
                }
            }.padding(24).frame(maxWidth: 660, alignment: .leading).frame(maxWidth: .infinity)
        }.navigationTitle("Your attempt")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
    }
}

private struct PassportPocketGuideView: View {
    @Environment(AdultStore.self) private var guides
    @State private var query = ""
    @State private var savedOnly = false
    var body: some View {
        List {
            Section {
                Toggle("Saved guides only", isOn: $savedOnly)
                Text("The existing pocket guide stays available. No guide step automatically earns a badge.")
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(guides.articles.filter { $0.matches(query) && (!savedOnly || guides.progress($0.id).isSaved) }) { article in
                NavigationLink {
                    GuideReaderView(article: article, onReminder: {}, isPassportReview: true)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text(article.summary).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.padding(.vertical, 8)
                    } icon: { Image(systemName: article.symbol).accessibilityHidden(true) }
                }
            }
        }.searchable(text: $query, prompt: "Search every bundled guide").navigationTitle("Pocket guide")
    }
}

private struct PassportCollectionView: View {
    @Environment(AdultPassportStore.self) private var passport
    @State private var showsSash = true
    @State private var query = ""
    private var achievements: [PassportAchievement] {
        passport.achievements.filter { $0.status == .earned && (query.isEmpty || ($0.guideTitle + " " + $0.entry.outcome).localizedStandardContains(query)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PassportHeading(eyebrow: "PRIVATE & SELF-REPORTED", title: "Your own kind of capable.", subtitle: "\(passport.achievements.filter { $0.status == .earned }.count) earned · no finish line")
                Picker("Achievement view", selection: $showsSash) {
                    Text("Sash").tag(true)
                    Text("Collection").tag(false)
                }.pickerStyle(.segmented)
                TextField("Find an achievement", text: $query).textFieldStyle(.roundedBorder)
                if let issue = passport.storageIssue {
                    Text(issue).fixedSize(horizontal: false, vertical: true)
                    Button("Retry opening passport") { passport.reloadLocalFiles() }
                }
                if achievements.isEmpty {
                    if query.isEmpty {
                        ContentUnavailableView("Room for your first little win", systemImage: "seal", description: Text("Try a task in Explore, then decide whether to record it."))
                    } else { ContentUnavailableView.search(text: query) }
                } else {
                    if showsSash {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(AdultPalette.accent.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AdultPalette.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 4])).padding(7))
                                .frame(width: 100, height: 230).rotationEffect(.degrees(38)).accessibilityHidden(true)
                            Text("Made of small attempts.").font(.title2.bold()).multilineTextAlignment(.center).padding(28)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }.frame(minHeight: 250).frame(maxWidth: .infinity)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(achievements) { achievement in
                            NavigationLink {
                                PassportAchievementView(badgeID: achievement.canonicalBadgeID)
                            } label: {
                                HStack(alignment: .top, spacing: 18) {
                                    if !showsSash || achievement.visibleOnSash {
                                        PassportBadgeMark(symbol: "tag", kind: achievement.entry.badgeKind).frame(width: 64, height: 76).accessibilityHidden(true)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(achievement.guideTitle).font(.headline).fixedSize(horizontal: false, vertical: true)
                                        Text(achievement.confidence.title).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                        if !achievement.visibleOnSash { Label("Hidden from sash", systemImage: "eye.slash").font(.caption) }
                                        Text("Self-reported achievement").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                                }.foregroundStyle(.primary).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(showsSash && achievement.visibleOnSash ? AdultPalette.accent.opacity(0.09) : Color.clear)
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }.navigationTitle("My sash")
    }
}

private struct PassportAchievementView: View {
    @Environment(AdultPassportStore.self) private var passport
    let badgeID: String
    @State private var confirmsUndo = false
    private var achievement: PassportAchievement? { passport.achievements.first { $0.canonicalBadgeID == badgeID } }
    var body: some View {
        if let achievement {
            Form {
                Section {
                    Text(achievement.guideTitle).font(.title2.bold()).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                    Text(achievement.entry.outcome).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text("Self-reported achievement").font(.headline)
                    Text(achievement.chosenDate, style: .date)
                    Text(achievement.entry.criterion).fixedSize(horizontal: false, vertical: true)
                    if !passport.isCurrent(achievement) {
                        Label("Historical record. This task version is no longer available to earn.", systemImage: "clock.arrow.circlepath")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if achievement.status == .removed { Text("This accidental claim was undone. The original record is retained privately.").fixedSize(horizontal: false, vertical: true) }
                }
                if achievement.status == .earned {
                    Section("My confidence") {
                        ForEach(PassportConfidence.allCases, id: \.self) { confidence in
                            Button { passport.setConfidence(confidence, for: badgeID) } label: {
                                HStack {
                                    Text(confidence.title).fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    if achievement.confidence == confidence { Image(systemName: "checkmark").accessibilityHidden(true) }
                                }.padding(.vertical, 8).contentShape(Rectangle())
                            }.accessibilityAddTraits(achievement.confidence == confidence ? .isSelected : [])
                        }
                    }
                    Section {
                        Toggle("Show on my sash", isOn: Binding(get: { achievement.visibleOnSash }, set: { passport.setSashVisibility($0, for: badgeID) }))
                        Text("Hiding keeps your private achievement. A refresher keeps its history, too.")
                            .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Section { Button("Undo accidental claim", role: .destructive) { confirmsUndo = true }.frame(minHeight: 44) }
                }
            }.navigationTitle("Achievement")
                .confirmationDialog("Undo this self-report?", isPresented: $confirmsUndo, titleVisibility: .visible) {
                    Button("Undo claim", role: .destructive) { passport.removeAchievement(badgeID) }
                    Button("Keep achievement", role: .cancel) {}
                }.disabled(!passport.canSave)
        }
    }
}

private struct PassportHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow).font(.caption.bold()).foregroundStyle(AdultPalette.accent).tracking(1)
            Text(title).font(.system(.largeTitle, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PassportBadgeMark: View {
    let symbol: String
    let kind: PassportBadgeKind
    var body: some View {
        ZStack {
            PassportBadgeShape(prepared: kind == .prepared).fill(AdultPalette.accent.opacity(0.12))
            PassportBadgeShape(prepared: kind == .prepared).stroke(AdultPalette.accent, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).padding(4)
            Image(systemName: symbol).font(.title2).foregroundStyle(AdultPalette.accent)
        }
    }
}

private struct PassportBadgeShape: Shape {
    var prepared: Bool
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = prepared ? [
            CGPoint(x: 0, y: 0), CGPoint(x: rect.width, y: 0), CGPoint(x: rect.width, y: rect.height * 0.7),
            CGPoint(x: rect.midX, y: rect.height), CGPoint(x: 0, y: rect.height * 0.7)
        ] : [
            CGPoint(x: rect.midX, y: 0), CGPoint(x: rect.width, y: rect.height * 0.25), CGPoint(x: rect.width, y: rect.height * 0.75),
            CGPoint(x: rect.midX, y: rect.height), CGPoint(x: 0, y: rect.height * 0.75), CGPoint(x: 0, y: rect.height * 0.25)
        ]
        return Path { path in path.addLines(points); path.closeSubpath() }
    }
}
#endif
