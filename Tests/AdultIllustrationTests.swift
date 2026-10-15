import XCTest
@testable import HowToAdult

final class AdultIllustrationTests: XCTestCase {
    private let catalogURL = URL(string: "https://example.invalid/v1/catalog")!
    private let digest = String(repeating: "a", count: 64)

    private func catalog() throws -> AdultCatalog {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: "catalog", withExtension: "json") ?? Bundle.main.url(forResource: "catalog", withExtension: "json")
        return try AdultCatalog.decode(Data(contentsOf: XCTUnwrap(url)))
    }

    private func fixture(_ catalog: AdultCatalog, edit: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let article = try XCTUnwrap(catalog.articles.first)
        func item(_ stepID: String) -> [String: Any] {
            ["guideID": article.id, "stepID": stepID, "assetSHA256": digest,
             "altText": "Two piles of laundry separated by color.", "caption": "Separate before washing.",
             "creator": "How to Adult", "license": "Original artwork", "provenance": "Native test fixture"]
        }
        var value: [String: Any] = ["schemaVersion": 1, "revision": catalog.revision,
                                    "items": [item(""), item(try XCTUnwrap(article.steps.first).id)]]
        edit(&value)
        return try JSONSerialization.data(withJSONObject: value)
    }

    private func newer(_ catalog: AdultCatalog) -> AdultCatalog {
        AdultCatalog(schemaVersion: catalog.schemaVersion, revision: catalog.revision + "-new",
                     publishedAt: "2099-01-01T00:00:00Z", categories: catalog.categories, articles: catalog.articles)
    }

    private func prepareDirectory(_ catalog: AdultCatalog) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(catalog).write(to: directory.appendingPathComponent("seed.json"))
        return directory
    }

    func testHeroAndStepSlotsDecodeAgainstExactCatalog() throws {
        let catalog = try catalog()
        let manifest = try AdultIllustrations.decode(fixture(catalog), for: catalog)
        let article = try XCTUnwrap(catalog.articles.first)
        XCTAssertEqual(manifest.illustration(guideID: article.id)?.stepID, "")
        XCTAssertEqual(manifest.illustration(guideID: article.id, stepID: article.steps[0].id)?.assetSHA256, digest)
        XCTAssertNil(manifest.illustration(guideID: article.id, stepID: "missing"))
        XCTAssertThrowsError(try AdultIllustrations.decode(fixture(catalog), for: newer(catalog)))
    }

    func testEmptyLegacySidecarIsValid() throws {
        let catalog = try catalog()
        let data = try fixture(catalog) { $0["items"] = [[String: Any]]() }
        XCTAssertTrue(try AdultIllustrations.decode(data, for: catalog).items.isEmpty)
    }

    func testInvalidSlotsAndMetadataAreRejected() throws {
        let catalog = try catalog()
        for (field, badValue) in [("guideID", "missing"), ("stepID", "missing"),
                                  ("assetSHA256", "https://other.invalid/image.png"),
                                  ("assetSHA256", digest + "\n"), ("altText", " \n"),
                                  ("altText", String(repeating: "x", count: 501)), ("license", "")] {
            let data = try fixture(catalog) { value in
                var items = value["items"] as! [[String: Any]]
                items[0][field] = badValue
                value["items"] = items
            }
            XCTAssertThrowsError(try AdultIllustrations.decode(data, for: catalog), field)
        }
        let duplicate = try fixture(catalog) { value in
            let items = value["items"] as! [[String: Any]]
            value["items"] = [items[0], items[0]]
        }
        XCTAssertThrowsError(try AdultIllustrations.decode(duplicate, for: catalog))
        let futureSchema = try fixture(catalog) { $0["schemaVersion"] = 2 }
        XCTAssertThrowsError(try AdultIllustrations.decode(futureSchema, for: catalog))
        XCTAssertThrowsError(try AdultIllustrations.decode(Data(repeating: 0, count: AdultIllustrations.maximumBytes + 1), for: catalog))
    }

    func testURLsAreImmutableSameOriginAndContainNoCredentials() throws {
        let revision = "2026-10-03-starter-1"
        XCTAssertEqual(AdultIllustrations.manifestURL(catalogURL: catalogURL, revision: revision)?.absoluteString,
                       "https://example.invalid/v1/illustrations/2026-10-03-starter-1")
        XCTAssertEqual(AdultIllustrations.assetURL(catalogURL: catalogURL, digest: digest)?.absoluteString,
                       "https://example.invalid/v1/assets/" + digest)
        let noisy = URL(string: "https://example.invalid/v1/catalog?ignored=value#fragment")!
        XCTAssertEqual(AdultIllustrations.manifestURL(catalogURL: noisy, revision: revision),
                       AdultIllustrations.manifestURL(catalogURL: catalogURL, revision: revision))
        for revision in ["", "../latest", "a/b", "a?b", "a\n", String(repeating: "a", count: 97)] {
            XCTAssertNil(AdultIllustrations.manifestURL(catalogURL: catalogURL, revision: revision))
        }
        for raw in ["http://example.invalid/v1/catalog", "https://user:password@example.invalid/v1/catalog",
                    "https://example.invalid/v1/illustrations"] {
            XCTAssertNil(AdultIllustrations.manifestURL(catalogURL: URL(string: raw)!, revision: revision))
        }
    }

    @MainActor func testExactManifestFetchPersistsForColdOfflineReload() async throws {
        let catalog = try catalog()
        let data = try fixture(catalog)
        let directory = try prepareDirectory(catalog)
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = try XCTUnwrap(AdultIllustrations.manifestURL(catalogURL: catalogURL, revision: catalog.revision))
        let store = AdultStore(directory: directory, bundledURL: directory.appendingPathComponent("seed.json"), remoteURL: catalogURL) { url in
            guard url == expected else { throw CatalogError.invalid }
            return data
        }
        await store.refreshIllustrations()
        XCTAssertEqual(store.illustrations?.revision, catalog.revision)
        let offline = AdultStore(directory: directory, bundledURL: directory.appendingPathComponent("seed.json"), remoteURL: catalogURL) { _ in
            throw CatalogError.unavailable
        }
        await offline.refreshIllustrations()
        XCTAssertEqual(offline.illustrations?.items.count, 2)
        XCTAssertNil(offline.updateIssue)
        XCTAssertEqual(offline.articles.count, catalog.articles.count)
    }

    @MainActor func testArtworkOnlyPrivateSessionCannotRefreshCatalog() async throws {
        let catalog = try catalog()
        let data = try fixture(catalog)
        let directory = try prepareDirectory(catalog)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AdultStore(directory: directory, bundledURL: directory.appendingPathComponent("seed.json"), remoteURL: catalogURL,
                               allowsRemoteUpdates: false, allowsNotifications: false, allowsArtworkReads: true) { _ in data }
        XCTAssertFalse(store.canRefresh)
        await store.refresh()
        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.illustrations)
        await store.refreshIllustrations()
        XCTAssertEqual(store.illustrations?.revision, catalog.revision)
        XCTAssertNil(store.updateIssue)
    }

    @MainActor func testWrongRevisionCacheAndFailedFetchLeaveTextAndProgressUsable() async throws {
        let catalog = try catalog()
        let directory = try prepareDirectory(catalog)
        defer { try? FileManager.default.removeItem(at: directory) }
        try fixture(newer(catalog)).write(to: directory.appendingPathComponent("illustrations-cache-v1.json"))
        let store = AdultStore(directory: directory, bundledURL: directory.appendingPathComponent("seed.json"), remoteURL: catalogURL) { _ in
            throw CatalogError.unavailable
        }
        await store.refreshIllustrations()
        XCTAssertNil(store.illustrations)
        XCTAssertNil(store.updateIssue)
        let article = try XCTUnwrap(store.articles.first)
        store.toggleSaved(article.id)
        store.toggleStep(article.steps[0], in: article)
        XCTAssertTrue(store.progress(article.id).isSaved)
        XCTAssertTrue(store.progress(article.id).isChecked(article.steps[0]))
    }

    @MainActor func testLateOldManifestCannotReplaceNewCatalogArtwork() async throws {
        let catalog = try catalog()
        let directory = try prepareDirectory(catalog)
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = IllustrationDownloadGate()
        let store = AdultStore(directory: directory, bundledURL: directory.appendingPathComponent("seed.json"), remoteURL: catalogURL) { url in
            try await gate.download(url)
        }
        let pending = Task { await store.refreshIllustrations() }
        await gate.waitUntilStarted()
        // A second request for this immutable revision is coalesced.
        await store.refreshIllustrations()
        try JSONEncoder().encode(newer(catalog)).write(to: directory.appendingPathComponent("catalog-cache-v1.json"))
        store.reloadLocalFiles()
        await gate.finish(with: try fixture(catalog))
        await pending.value
        XCTAssertEqual(store.catalog?.revision, newer(catalog).revision)
        XCTAssertNil(store.illustrations)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("illustrations-cache-v1.json").path))
    }

    @MainActor func testMismatchedNetworkManifestIsNotCached() async throws {
        let catalog = try catalog()
        let data = try fixture(newer(catalog))
        let directory = try prepareDirectory(catalog)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AdultStore(directory: directory, bundledURL: directory.appendingPathComponent("seed.json"), remoteURL: catalogURL) { _ in data }
        await store.refreshIllustrations()
        XCTAssertNil(store.illustrations)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("illustrations-cache-v1.json").path))
    }
}

private actor IllustrationDownloadGate {
    private var request: CheckedContinuation<Data, Error>?
    private var started: CheckedContinuation<Void, Never>?

    func download(_ url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            request = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if request != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(with data: Data) {
        request?.resume(returning: data)
        request = nil
    }
}
