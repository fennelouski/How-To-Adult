import XCTest
@testable import HowToAdult

final class AdultCoreTests: XCTestCase {
    private func catalogData() throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: "catalog", withExtension: "json") ?? Bundle.main.url(forResource: "catalog", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testBundledLibraryIsCompleteAndValidated() throws {
        let catalog = try AdultCatalog.decode(catalogData())
        XCTAssertGreaterThanOrEqual(catalog.articles.count, 48)
        XCTAssertEqual(catalog.categories.count, 7)
        XCTAssertTrue(catalog.articles.contains { $0.jurisdiction == "United States" && !$0.sources.isEmpty })
        for category in catalog.categories { XCTAssertTrue(catalog.articles.contains { $0.categoryID == category.id }) }
    }

    func testMalformedRemoteCatalogCannotReplaceTheLibrary() throws {
        let data = try catalogData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = 999
        XCTAssertThrowsError(try AdultCatalog.decode(JSONSerialization.data(withJSONObject: object)))
        object["schemaVersion"] = 1
        var articles = try XCTUnwrap(object["articles"] as? [[String: Any]])
        articles.append(try XCTUnwrap(articles.first))
        object["articles"] = articles
        XCTAssertThrowsError(try AdultCatalog.decode(JSONSerialization.data(withJSONObject: object)))
    }

    func testSearchUsesAllTokensAndIgnoresCase() throws {
        let article = try XCTUnwrap(AdultCatalog.decode(catalogData()).articles.first)
        XCTAssertTrue(article.matches(""))
        XCTAssertTrue(article.matches(article.title.uppercased()))
        XCTAssertFalse(article.matches(article.title + " impossibleunmatchedword"))
    }

    func testChangedInstructionsMustBeCheckedAgain() {
        let original = GuideStep(id: "first", title: "Check the label", body: "Use the recommended cycle.")
        let edited = GuideStep(id: "first", title: "Check the label", body: "Use the recommended cycle and temperature.")
        var progress = ArticleProgress()
        progress.checkedSteps[original.id] = original.fingerprint
        XCTAssertTrue(progress.isChecked(original))
        XCTAssertFalse(progress.isChecked(edited))
    }

    func testUnsupportedPersonalStorageIsRejected() throws {
        XCTAssertThrowsError(try UserLibrary.decode(Data("{\"schemaVersion\":2,\"articles\":{}}".utf8)))
    }

    func testSharedFinancialGuideRetainsSafetyAndSourceContext() throws {
        let article = try XCTUnwrap(AdultCatalog.decode(catalogData()).articles.first { $0.id == "start-with-your-401k" })
        XCTAssertTrue(article.shareText.contains("United States rules"))
        for caution in article.cautions { XCTAssertTrue(article.shareText.contains(caution)) }
        for source in article.sources { XCTAssertTrue(article.shareText.contains(source.url)) }
        XCTAssertTrue(article.shareText.contains(article.updatedAt))
    }

    @MainActor func testBookmarksAndChecksSurviveColdReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("seed.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try catalogData().write(to: url)
        let first = AdultStore(directory: directory, bundledURL: url)
        let article = try XCTUnwrap(first.articles.first)
        let step = try XCTUnwrap(article.steps.first)
        first.toggleSaved(article.id)
        first.toggleStep(step, in: article)
        let second = AdultStore(directory: directory, bundledURL: url)
        XCTAssertTrue(second.progress(article.id).isSaved)
        XCTAssertTrue(second.progress(article.id).isChecked(step))
        second.toggleStep(step, in: article)
        XCTAssertFalse(second.progress(article.id).isChecked(step))
    }

    @MainActor func testCorruptPersonalStorageIsPreservedAndWritesBlocked() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("seed.json")
        try catalogData().write(to: url)
        let personal = directory.appendingPathComponent("UserLibrary-v1.json")
        let broken = Data("user recovery evidence".utf8)
        try broken.write(to: personal)
        let store = AdultStore(directory: directory, bundledURL: url)
        XCTAssertFalse(store.canSave)
        store.toggleSaved(try XCTUnwrap(store.articles.first).id)
        XCTAssertEqual(try Data(contentsOf: personal), broken)
        XCTAssertNotNil(store.storageIssue)
    }

    @MainActor func testBadDownloadedCatalogFallsBackToEmbeddedGuides() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("seed.json")
        try catalogData().write(to: url)
        try Data("bad download".utf8).write(to: directory.appendingPathComponent("catalog-cache-v1.json"))
        let store = AdultStore(directory: directory, bundledURL: url)
        XCTAssertGreaterThanOrEqual(store.articles.count, 48)
        XCTAssertTrue(store.canSave)
        XCTAssertNotNil(store.updateIssue)
    }
    @MainActor func testRemovingReminderPreservesBookmarkAndCheckedSteps() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let seed = directory.appendingPathComponent("seed.json")
        try catalogData().write(to: seed)
        let article = try XCTUnwrap(AdultCatalog.decode(catalogData()).articles.first)
        let step = try XCTUnwrap(article.steps.first)
        var personal = UserLibrary()
        var progress = ArticleProgress()
        progress.isSaved = true
        progress.checkedSteps[step.id] = step.fingerprint
        progress.reminderDate = Date().addingTimeInterval(3_600)
        progress.reminderSound = false
        personal.articles[article.id] = progress
        try JSONEncoder().encode(personal).write(to: directory.appendingPathComponent("UserLibrary-v1.json"))
        let store = AdultStore(directory: directory, bundledURL: seed)
        XCTAssertTrue(store.upcoming.contains { $0.id == article.id })
        XCTAssertTrue(store.cancelReminder(article.id))
        XCTAssertFalse(store.upcoming.contains { $0.id == article.id })
        let reloaded = AdultStore(directory: directory, bundledURL: seed)
        XCTAssertNil(reloaded.progress(article.id).reminderDate)
        XCTAssertTrue(reloaded.progress(article.id).isSaved)
        XCTAssertTrue(reloaded.progress(article.id).isChecked(step))
        XCTAssertFalse(reloaded.progress(article.id).reminderSound)
    }

}
