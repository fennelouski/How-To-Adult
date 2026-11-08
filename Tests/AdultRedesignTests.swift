import XCTest
import CoreGraphics
@testable import HowToAdult

final class AdultRedesignTests: XCTestCase {
    private func catalog() throws -> AdultCatalog {
        let url = Bundle(for: Self.self).url(forResource: "catalog", withExtension: "json") ?? Bundle.main.url(forResource: "catalog", withExtension: "json")
        return try AdultCatalog.decode(Data(contentsOf: XCTUnwrap(url)))
    }

    @MainActor private func makeStore(seedLibrary: Data? = nil) throws -> (AdultStore, URL, () -> AdultStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let seed = directory.appendingPathComponent("seed.json")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "catalog", withExtension: "json") ?? Bundle.main.url(forResource: "catalog", withExtension: "json"))
        try Data(contentsOf: url).write(to: seed)
        if let seedLibrary { try seedLibrary.write(to: directory.appendingPathComponent("UserLibrary-v1.json")) }
        let make = { AdultStore(directory: directory, bundledURL: seed, allowsRemoteUpdates: false, allowsNotifications: false) }
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return (make(), directory, make)
    }

    // MARK: Migration

    @MainActor func testShippedLibraryMigratesAndStaysReadableByOlderDecoder() throws {
        // Exact shape written by the submitted 1.0 build.
        let shipped = Data(#"{"schemaVersion":1,"articles":{"wash-your-first-load":{"isSaved":true,"checkedSteps":{},"reminderSound":true,"rating":3}}}"#.utf8)
        let (store, directory, reload) = try makeStore(seedLibrary: shipped)
        let article = try XCTUnwrap(store.article("wash-your-first-load"))
        XCTAssertTrue(store.progress(article.id).isSaved)
        XCTAssertNil(store.progress(article.id).knownSteps)

        XCTAssertTrue(store.setMark(.known, for: article.steps[0], in: article))
        store.toggleFavorite(article.steps[1], in: article)

        let written = try Data(contentsOf: directory.appendingPathComponent("UserLibrary-v1.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: written) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 1, "Additive change keeps the schema version the 1.0 build accepts")
        // A 1.0-shaped decoder ignores the new keys and keeps existing data.
        struct OldProgress: Decodable { let isSaved: Bool; let checkedSteps: [String: String]; let rating: Int? }
        struct OldLibrary: Decodable { let schemaVersion: Int; let articles: [String: OldProgress] }
        let old = try JSONDecoder().decode(OldLibrary.self, from: written)
        XCTAssertEqual(old.articles[article.id]?.isSaved, true)
        XCTAssertEqual(old.articles[article.id]?.rating, 3)

        let reloaded = reload()
        XCTAssertTrue(reloaded.progress(article.id).isKnown(article.steps[0]))
        XCTAssertTrue(reloaded.progress(article.id).isFavorite(article.steps[1]))
        XCTAssertTrue(reloaded.progress(article.id).isSaved)
    }

    func testOversizedNewFieldsAreRejected() {
        let ids = (0...80).map { "\"s\($0)\"" }.joined(separator: ",")
        XCTAssertThrowsError(try UserLibrary.decode(Data(#"{"schemaVersion":1,"articles":{"a":{"isSaved":false,"checkedSteps":{},"reminderSound":true,"favoriteSteps":[\#(ids)]}}}"#.utf8)))
    }

    // MARK: Known vs done

    @MainActor func testDoneAndKnownAreExclusiveAndBothCountTowardProgress() throws {
        let (store, _, reload) = try makeStore()
        let article = try XCTUnwrap(store.article("cook-a-pot-of-rice"))
        let (a, b) = (article.steps[0], article.steps[1])
        store.setMark(.done, for: a, in: article)
        store.setMark(.known, for: b, in: article)
        var p = store.progress(article.id)
        XCTAssertEqual(p.mark(a), .done)
        XCTAssertEqual(p.mark(b), .known)
        XCTAssertEqual(p.handledCount(in: article), 2)
        XCTAssertTrue(p.isInProgress(article))
        XCTAssertEqual(store.inProgress.map(\.id), [article.id])

        store.setMark(.known, for: a, in: article)
        p = store.progress(article.id)
        XCTAssertFalse(p.isChecked(a), "Known replaces done")
        XCTAssertTrue(p.isKnown(a))

        store.setMark(nil, for: a, in: article) // undo
        XCTAssertNil(store.progress(article.id).mark(a))
        XCTAssertNil(reload().progress(article.id).mark(a))
        // toggleStep keeps its old meaning and clears a known mark.
        store.toggleStep(b, in: article)
        XCTAssertEqual(store.progress(article.id).mark(b), .done)
    }

    @MainActor func testWholeGuideKnownKeepsDoneStepsAndIsUndoable() throws {
        let (store, _, _) = try makeStore()
        let article = try XCTUnwrap(store.article("make-scrambled-eggs"))
        store.setMark(.done, for: article.steps[0], in: article)
        store.setGuideKnown(true, article)
        var p = store.progress(article.id)
        XCTAssertTrue(p.isFinished(article))
        XCTAssertFalse(p.isKnownGuide(article), "One step was actually done")
        XCTAssertEqual(p.mark(article.steps[0]), .done)
        XCTAssertFalse(p.isInProgress(article))
        XCTAssertTrue(store.inProgress.isEmpty, "Finished guides leave Now")

        store.setGuideKnown(false, article)
        p = store.progress(article.id)
        XCTAssertEqual(p.handledCount(in: article), 1)

        let other = try XCTUnwrap(store.article("thaw-food-safely"))
        store.setGuideKnown(true, other)
        XCTAssertTrue(store.progress(other.id).isKnownGuide(other))
    }

    func testEditedStepNeedsMarkingAgain() {
        let step = GuideStep(id: "a", title: "Sort", body: "Old")
        var p = ArticleProgress()
        p.knownSteps = [step.id: step.fingerprint]
        XCTAssertEqual(p.mark(step), .known)
        XCTAssertNil(p.mark(GuideStep(id: "a", title: "Sort", body: "New")))
    }

    @MainActor func testFavoriteStepToggleAndUnknownStepIgnored() throws {
        let (store, _, _) = try makeStore()
        let article = try XCTUnwrap(store.article("make-a-first-budget"))
        store.toggleFavorite(article.steps[2], in: article)
        XCTAssertTrue(store.progress(article.id).isFavorite(article.steps[2]))
        store.toggleFavorite(article.steps[2], in: article)
        XCTAssertNil(store.progress(article.id).favoriteSteps)
        store.toggleFavorite(GuideStep(id: "not-here", title: "x", body: "y"), in: article)
        XCTAssertNil(store.progress(article.id).favoriteSteps)
        XCTAssertFalse(store.setMark(.done, for: GuideStep(id: "not-here", title: "x", body: "y"), in: article))
    }

    // MARK: Browse

    func testEveryGuideIsInItsCategoryAndMostHaveASubArea() throws {
        let catalog = try catalog()
        var covered = 0
        for article in catalog.articles {
            let areas = GuideSubArea.all(for: article.categoryID)
            XCTAssertFalse(areas.isEmpty, article.categoryID)
            if areas.contains(where: { $0.contains(article) }) { covered += 1 }
        }
        XCTAssertGreaterThanOrEqual(Double(covered) / Double(catalog.articles.count), 0.9, "Sub-area tags drifted from the catalog")
        for category in catalog.categories {
            XCTAssertFalse(GuideSubArea.available(for: category.id, in: catalog.articles).isEmpty)
        }
    }

    func testFiltersCombine() throws {
        let articles = try catalog().articles
        var saved = ArticleProgress(); saved.isSaved = true
        let known = articles.first { $0.id == "thaw-food-safely" }!
        var knownProgress = ArticleProgress(); knownProgress.knownSteps = Dictionary(uniqueKeysWithValues: known.steps.map { ($0.id, $0.fingerprint) })
        let lookup: (String) -> ArticleProgress = { id in id == "check-your-credit-report" ? saved : id == known.id ? knownProgress : ArticleProgress() }

        var filter = GuideFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.apply(articles, progress: lookup).count, articles.count)
        filter.favoritesOnly = true
        XCTAssertEqual(filter.apply(articles, progress: lookup).map(\.id), ["check-your-credit-report"])
        filter.region = .general
        XCTAssertTrue(filter.apply(articles, progress: lookup).isEmpty)
        filter = GuideFilter(hideKnown: true)
        XCTAssertFalse(filter.apply(articles, progress: lookup).contains { $0.id == known.id })
        filter = GuideFilter(quickOnly: true, region: .unitedStates)
        XCTAssertTrue(filter.apply(articles, progress: lookup).allSatisfy { $0.minutes <= 10 && $0.jurisdiction != "General" })
    }

    // MARK: Carousel

    func testCarouselPagesClampAndResume() throws {
        var c = GuideCarousel(stepCount: 4)
        XCTAssertEqual(c.pageCount, 6)
        XCTAssertEqual(c.page, .overview)
        XCTAssertFalse(c.canGoBack)
        c.back(); XCTAssertEqual(c.index, 0)
        c.forward(); XCTAssertEqual(c.page, .step(0)); XCTAssertEqual(c.stepIndex, 0)
        c.go(to: 99); XCTAssertEqual(c.page, .finish); XCTAssertFalse(c.canGoForward)
        c.forward(); XCTAssertEqual(c.index, 5)
        c.go(to: 4); XCTAssertEqual(c.page, .step(3))

        let article = try XCTUnwrap(catalog().articles.first)
        var p = ArticleProgress()
        XCTAssertEqual(GuideCarousel.resumeIndex(for: article, progress: p), 0)
        p.checkedSteps[article.steps[0].id] = article.steps[0].fingerprint
        p.knownSteps = [article.steps[1].id: article.steps[1].fingerprint]
        XCTAssertEqual(GuideCarousel.resumeIndex(for: article, progress: p), 3, "First open step is step 3, page 3")
        for step in article.steps { p.checkedSteps[step.id] = step.fingerprint }
        XCTAssertEqual(GuideCarousel.resumeIndex(for: article, progress: p), 0)
    }

    // MARK: Ask an AI / search

    func testPromptRenderIsSinglePassAndKeepsUnknownPlaceholders() {
        let out = AskAIPrompt.render("A {guide} B {step} {missing} {unclosed", values: ["guide": "use {step} and {{x}}", "step": "S"])
        XCTAssertEqual(out, "A use {step} and {{x}} B S {missing} {unclosed")
        XCTAssertEqual(AskAIPrompt.render("", values: ["guide": "x"]), "")
        XCTAssertEqual(AskAIPrompt.render("{}{guide}}", values: ["guide": "g"]), "{}g}")
    }

    func testPromptUsesGuideStepAndExcludesNotesUnlessAsked() throws {
        let article = try XCTUnwrap(catalog().articles.first { $0.id == "check-your-credit-report" })
        var p = ArticleProgress(); p.personalNotes = "private thing"
        p.checkedSteps[article.steps[0].id] = article.steps[0].fingerprint
        let prompt = AskAIPrompt.make(template: nil, article: article, stepIndex: 1, progress: p, includeNotes: false)
        XCTAssertTrue(prompt.contains(article.title))
        XCTAssertTrue(prompt.contains("Step 2 of 4: " + article.steps[1].title))
        XCTAssertTrue(prompt.contains(article.steps[1].body))
        XCTAssertTrue(prompt.contains("United States"))
        XCTAssertTrue(prompt.contains("1 done"))
        XCTAssertFalse(prompt.contains("private thing"))
        XCTAssertFalse(prompt.contains("{"), "Default template fully resolves")
        XCTAssertTrue(AskAIPrompt.make(template: "N: {notes}", article: article, stepIndex: nil, progress: p, includeNotes: true).contains("private thing"))
        XCTAssertEqual(AskAIPrompt.make(template: "  \n", article: article, stepIndex: nil, progress: p, includeNotes: false),
                       AskAIPrompt.make(template: nil, article: article, stepIndex: nil, progress: p, includeNotes: false), "Blank template falls back")
        XCTAssertTrue(AskAIPrompt.make(template: nil, article: article, stepIndex: nil, progress: p, includeNotes: false).contains("the guide as a whole"))
    }

    func testGoogleURLPercentEncodesEverythingMeaningful() throws {
        let url = try XCTUnwrap(WebSearch.googleURL("  C++ & tax #1 = 100% café/rent? "))
        XCTAssertEqual(url.absoluteString, "https://www.google.com/search?q=C%2B%2B%20%26%20tax%20%231%20%3D%20100%25%20caf%C3%A9%2Frent%3F")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "C++ & tax #1 = 100% café/rent?")
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertNil(WebSearch.googleURL("   "))
        let article = try XCTUnwrap(catalog().articles.first { $0.id == "cook-a-pot-of-rice" })
        XCTAssertEqual(WebSearch.query(article: article, stepIndex: nil), "how to cook a pot of rice")
        XCTAssertTrue(WebSearch.query(article: article, stepIndex: 0).hasPrefix(article.steps[0].title))
        XCTAssertTrue(AIDestination.allCases.allSatisfy { $0 == .none || $0.url?.scheme == "https" })
    }

    // MARK: Stamps

    func testStampsDistinguishDoneKnownAndCompleteTopics() throws {
        let catalog = try catalog()
        let food = catalog.articles.filter { $0.categoryID == "food" }
        var store: [String: ArticleProgress] = [:]
        for (i, article) in food.enumerated() {
            var p = ArticleProgress()
            for step in article.steps {
                if i == 0 { p.knownSteps = (p.knownSteps ?? [:]).merging([step.id: step.fingerprint]) { $1 } }
                else { p.checkedSteps[step.id] = step.fingerprint }
            }
            store[article.id] = p
        }
        let topics = TopicStamps.make(categories: catalog.categories, articles: catalog.articles) { store[$0] ?? ArticleProgress() }
        let foodTopic = try XCTUnwrap(topics.first { $0.id == "food" })
        XCTAssertTrue(foodTopic.isComplete)
        XCTAssertEqual(foodTopic.guides.first?.stamp, .known)
        XCTAssertEqual(foodTopic.guides.last?.stamp, .done)
        XCTAssertFalse(try XCTUnwrap(topics.first { $0.id == "home" }).isComplete)
        XCTAssertEqual(topics.first { $0.id == "home" }?.earned, 0)
    }

    // MARK: Presenter layout

    func testPresenterLayoutAdaptsToShapeAndMode() {
        let tv = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(PresenterLayout.make(size: tv, mode: .current, stepCount: 4).columns, 1)
        XCTAssertEqual(PresenterLayout.make(size: tv, mode: .expanded, stepCount: 4).columns, 2)
        XCTAssertEqual(PresenterLayout.make(size: tv, mode: .whole, stepCount: 4).columns, 4)
        XCTAssertEqual(PresenterLayout.make(size: tv, mode: .whole, stepCount: 2).columns, 2, "Never more columns than steps")
        let portrait = CGSize(width: 1080, height: 1920)
        XCTAssertEqual(PresenterLayout.make(size: portrait, mode: .expanded, stepCount: 4).columns, 1)
        XCTAssertEqual(PresenterLayout.make(size: portrait, mode: .whole, stepCount: 4).columns, 2)
        XCTAssertEqual(PresenterLayout.make(size: CGSize(width: 3440, height: 1440), mode: .whole, stepCount: 6).columns, 4)
        XCTAssertEqual(PresenterLayout.make(size: .zero, mode: .whole, stepCount: 4), PresenterLayout(columns: 1, scale: 1))
        let small = PresenterLayout.make(size: CGSize(width: 640, height: 360), mode: .current, stepCount: 4)
        XCTAssertGreaterThanOrEqual(small.scale, 1)
        let big = PresenterLayout.make(size: CGSize(width: 3840, height: 2160), mode: .current, stepCount: 4)
        XCTAssertLessThanOrEqual(big.scale, 3)
        XCTAssertGreaterThan(big.scale, small.scale)
        XCTAssertGreaterThan(PresenterLayout.make(size: tv, mode: .current, stepCount: 4).scale,
                             PresenterLayout.make(size: tv, mode: .whole, stepCount: 4).scale)
    }
}
