import XCTest
import ImageIO
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

    @MainActor func testPersonalNotesAndRatingPreserveOlderProgressAndSurviveReload() throws {
        let older = Data("{\"schemaVersion\":1,\"articles\":{\"wash-your-first-load\":{\"isSaved\":true,\"checkedSteps\":{},\"reminderSound\":false}}}".utf8)
        let decoded = try UserLibrary.decode(older)
        XCTAssertNil(decoded.articles["wash-your-first-load"]?.personalNotes)
        XCTAssertNil(decoded.articles["wash-your-first-load"]?.rating)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let seed = directory.appendingPathComponent("seed.json")
        try catalogData().write(to: seed)
        try older.write(to: directory.appendingPathComponent("UserLibrary-v1.json"))
        let store = AdultStore(directory: directory, bundledURL: seed, allowsRemoteUpdates: false, allowsNotifications: false)
        XCTAssertTrue(store.saveNotes("Separate towels; use the care label.", for: "wash-your-first-load"))
        store.rate("wash-your-first-load", stars: 4)
        let reloaded = AdultStore(directory: directory, bundledURL: seed, allowsRemoteUpdates: false, allowsNotifications: false)
        XCTAssertEqual(reloaded.progress("wash-your-first-load").personalNotes, "Separate towels; use the care label.")
        XCTAssertEqual(reloaded.progress("wash-your-first-load").rating, 4)
        XCTAssertTrue(reloaded.progress("wash-your-first-load").isSaved)
        XCTAssertFalse(reloaded.progress("wash-your-first-load").reminderSound)
        XCTAssertFalse(reloaded.saveNotes(String(repeating: "x", count: 50_001), for: "wash-your-first-load"))
        XCTAssertFalse(reloaded.saveNotes("Stale window draft", for: "wash-your-first-load", expectedNotes: "Older notes"))
        XCTAssertEqual(reloaded.progress("wash-your-first-load").personalNotes, "Separate towels; use the care label.")
    }

    func testSharedFinancialGuideRetainsSafetyAndSourceContext() throws {
        let article = try XCTUnwrap(AdultCatalog.decode(catalogData()).articles.first { $0.id == "start-with-your-401k" })
        XCTAssertTrue(article.shareText.contains("United States rules"))
        XCTAssertTrue(article.shareText.contains("not professional financial, legal or medical advice"))
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

    @MainActor func testConfiguredLiveCatalogPreservesProgressAndColdCache() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HOWTOADULT_VERIFY_LIVE_CATALOG"] == "1",
                          "Live deployment verification runs explicitly; ordinary unit tests stay offline.")
        let configured = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "AdultCatalogURL") as? String)
        XCTAssertEqual(configured, "https://how-to-adult-guides.vercel.app/v1/catalog")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let seed = directory.appendingPathComponent("seed.json")
        try catalogData().write(to: seed)
        let store = AdultStore(directory: directory, bundledURL: seed)
        let article = try XCTUnwrap(store.articles.first)
        let step = try XCTUnwrap(article.steps.first)
        store.toggleSaved(article.id)
        store.toggleStep(step, in: article)
        XCTAssertTrue(store.canRefresh)
        await store.refresh()
        XCTAssertNil(store.updateIssue)
        XCTAssertGreaterThanOrEqual(store.articles.count, 56)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("catalog-cache-v1.json").path))
        let reloaded = AdultStore(directory: directory, bundledURL: seed)
        XCTAssertEqual(reloaded.catalog?.revision, store.catalog?.revision)
        XCTAssertTrue(reloaded.progress(article.id).isSaved)
        XCTAssertTrue(reloaded.progress(article.id).isChecked(step))
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



    @MainActor func testRevisionBoundIllustrationsPreserveOfflineGuidesAndProgress() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let seed = directory.appendingPathComponent("seed.json")
        try catalogData().write(to: seed)
        let service = try XCTUnwrap(URL(string: "https://how-to-adult-guides.vercel.app/v1/catalog"))
        let store = AdultStore(directory: directory, bundledURL: seed, remoteURL: service, allowsNotifications: false)
        let catalog = try XCTUnwrap(store.catalog)
        let article = try XCTUnwrap(catalog.articles.first)
        let step = try XCTUnwrap(article.steps.first)
        store.toggleSaved(article.id)
        XCTAssertTrue(store.saveNotes("Keep this private note.", for: article.id))
        let personalURL = directory.appendingPathComponent("UserLibrary-v1.json")
        let personalBytes = try Data(contentsOf: personalURL)

        // A generated two-pixel fixture stays in this temporary directory; it is not app artwork.
        let context = try XCTUnwrap(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: 2, height: 2))
        let png = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(png as CFMutableData, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let imageData = png as Data
        let item = GuideIllustration(guideID: article.id, stepID: step.id, assetSHA256: GuideIllustration.digest(imageData),
                                     altText: "Test pixels", caption: "", creator: "Test suite", license: "Test fixture", provenance: "Generated locally by this test")
        let manifest = GuideIllustrationManifest(schemaVersion: 1, revision: catalog.revision, items: [item])
        let data = try JSONEncoder().encode(manifest)
        try store.adoptIllustrations(data, for: catalog)
        XCTAssertEqual(store.illustration(for: article, stepID: step.id), item)
        XCTAssertNil(store.cachedIllustrationImage(item, revision: catalog.revision))
        XCTAssertNotNil(store.cacheIllustrationImage(imageData, for: item, revision: catalog.revision))
        let assetURL = directory.appendingPathComponent("illustration-assets-v1").appendingPathComponent(item.assetSHA256 + ".png")
        let sidecarURL = directory.appendingPathComponent("illustrations-cache-v1.json")
        let cachedBytes = try Data(contentsOf: sidecarURL)
        XCTAssertNil(store.cacheIllustrationImage(Data("bad pixels".utf8), for: item, revision: catalog.revision))
        XCTAssertEqual(try Data(contentsOf: assetURL), imageData)

        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for changed in ["revision", "schema", "duplicate", "unknownStep", "digestPath", "missingAlt"] {
            var invalid = original
            var entries = try XCTUnwrap(original["items"] as? [[String: Any]])
            switch changed {
            case "revision": invalid["revision"] = "some-other-revision"
            case "schema": invalid["schemaVersion"] = 2
            case "duplicate": entries.append(entries[0])
            case "unknownStep": entries[0]["stepID"] = "removed-step"
            case "digestPath": entries[0]["assetSHA256"] = "../untrusted"
            default: entries[0]["altText"] = " "
            }
            invalid["items"] = entries
            XCTAssertThrowsError(try store.adoptIllustrations(JSONSerialization.data(withJSONObject: invalid), for: catalog), changed)
            XCTAssertEqual(try Data(contentsOf: sidecarURL), cachedBytes)
        }
        let reloaded = AdultStore(directory: directory, bundledURL: seed, remoteURL: service, allowsNotifications: false)
        XCTAssertEqual(reloaded.illustration(for: article, stepID: step.id), item)
        XCTAssertNotNil(reloaded.cachedIllustrationImage(item, revision: catalog.revision))
        let differentService = AdultStore(directory: directory, bundledURL: seed, remoteURL: URL(string: "https://other.example/v1/catalog"), allowsNotifications: false)
        XCTAssertNil(differentService.illustrations)

        // Even a reused revision string cannot pair old artwork with changed guide text.
        var changedCatalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData()) as? [String: Any])
        var articles = try XCTUnwrap(changedCatalog["articles"] as? [[String: Any]])
        var steps = try XCTUnwrap(articles[0]["steps"] as? [[String: Any]])
        steps[0]["body"] = step.body + " Changed instruction."
        articles[0]["steps"] = steps
        changedCatalog["articles"] = articles
        let catalogCache = directory.appendingPathComponent("catalog-cache-v1.json")
        try JSONSerialization.data(withJSONObject: changedCatalog).write(to: catalogCache)
        let edited = AdultStore(directory: directory, bundledURL: seed, remoteURL: service, allowsNotifications: false)
        XCTAssertNil(edited.illustrations)
        XCTAssertThrowsError(try edited.adoptIllustrations(data, for: catalog))
        XCTAssertFalse(edited.articles.isEmpty)
        try FileManager.default.removeItem(at: catalogCache)

        let corrupt = Data("damaged optional sidecar".utf8)
        try corrupt.write(to: sidecarURL)
        let fallback = AdultStore(directory: directory, bundledURL: seed, remoteURL: service, allowsNotifications: false)
        XCTAssertNil(fallback.illustrations)
        XCTAssertFalse(fallback.articles.isEmpty)
        XCTAssertEqual(try Data(contentsOf: sidecarURL), corrupt)
        try cachedBytes.write(to: sidecarURL)
        try Data("damaged optional image".utf8).write(to: assetURL)
        XCTAssertNil(reloaded.cachedIllustrationImage(item, revision: catalog.revision))
        try FileManager.default.removeItem(at: assetURL)
        let fullCache = assetURL.deletingLastPathComponent().appendingPathComponent("budget-test.bin")
        try Data(repeating: 0, count: 32 * 1_024 * 1_024).write(to: fullCache)
        XCTAssertNotNil(reloaded.cacheIllustrationImage(imageData, for: item, revision: catalog.revision))
        XCTAssertFalse(FileManager.default.fileExists(atPath: assetURL.path))
        XCTAssertEqual(try Data(contentsOf: personalURL), personalBytes)
    }
}
