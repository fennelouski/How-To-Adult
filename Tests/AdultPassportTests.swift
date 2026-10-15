import XCTest
@testable import HowToAdult

final class AdultPassportTests: XCTestCase {
    private let world = PassportWorld(id: "home", title: "Home", symbol: "house", colorKey: "green")
    private let secondWorld = PassportWorld(id: "workshop", title: "Workshop", symbol: "wrench", colorKey: "blue")

    private func catalog(revision: String = "test-v1", body: String = "Sort a clean pair of socks.") -> AdultCatalog {
        AdultCatalog(schemaVersion: 1, revision: revision, publishedAt: "2026-10-08T07:00:00Z",
            categories: [GuideCategory(id: "home", title: "Home", symbol: "house", colorKey: "green")],
            articles: [AdultArticle(id: "sort-socks", title: "Sort socks", summary: "A low-risk test guide.",
                categoryID: "home", symbol: "socks", minutes: 2, jurisdiction: "General", updatedAt: "2026-10-08",
                tags: [], tools: [], steps: [GuideStep(id: "sort", title: "Sort", body: body),
                    GuideStep(id: "put-away", title: "Put away", body: "Place the pair in a drawer.")], cautions: [], sources: [])])
    }

    private func entry(catalog: AdultCatalog? = nil, badge: String = "sock-pair", skill: String = "pair-socks",
                       guide: String = "sort-socks", revision: String? = nil, digest: String? = nil,
                       assets: [String: String] = [:], worlds: [String] = ["home"], countries: [String] = ["US"],
                       review: PassportReviewState = .approved, publication: PassportPublicationState = .published,
                       award: PassportAwardState = .eligible, artwork: PassportArtworkState = .productionReady,
                       risk: PassportRisk = .low, kind: PassportBadgeKind = .skill) throws -> PassportEntry {
        let catalog = catalog ?? self.catalog()
        return PassportEntry(canonicalBadgeID: badge, canonicalSkillID: skill, guideID: guide,
            catalogRevision: revision ?? catalog.revision,
            bodySHA256: try digest ?? PassportManifest.articleFingerprint(catalog.articles[0]),
            instructionalAssets: assets, badgeAssetVersion: "test-art-v1", worldIDs: worlds,
            task: "Pair two clean socks.", outcome: "I paired two clean socks.", criterion: "One matching pair is put away.",
            warnings: ["Use clean socks."], reviewedCountryCodes: countries, review: review, publication: publication,
            award: award, artwork: artwork, risk: risk, badgeKind: kind)
    }

    private func manifest(_ entries: [PassportEntry], fixture: Bool = false) -> PassportManifest {
        PassportManifest(version: "test-manifest-v1", worlds: [world, secondWorld], entries: entries, reviewFixture: fixture)
    }

    @MainActor private func store(_ entries: [PassportEntry], directory: URL, catalog: AdultCatalog? = nil,
                                  country: String = "US", assets: [String: [String: String]] = [:],
                                  fixture: Bool = false, requestedFixture: Bool = false) -> AdultPassportStore {
        AdultPassportStore(directory: directory, manifest: manifest(entries, fixture: fixture),
            catalog: catalog ?? self.catalog(), countryCode: country, reviewFixture: requestedFixture, instructionalAssets: assets)
    }

    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    @MainActor func testMissingManifestKeepsPassportClosed() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = catalog()
        let store = AdultPassportStore(directory: directory, manifest: .empty, catalog: catalog, countryCode: "US")
        XCTAssertTrue(store.admittedEntries().isEmpty)
        XCTAssertTrue(store.worlds().isEmpty)
        XCTAssertFalse(store.award(try entry(), on: Date(), confidence: .canDo))
        XCTAssertTrue(catalog.articles[0].matches("socks"))
    }

    @MainActor func testReviewPublicationAwardAndArtworkGatesDenyDirectAward() throws {
        let entries = try [entry(review: .held), entry(review: .unreviewed), entry(publication: .withdrawn),
                           entry(publication: .unpublished), entry(award: .ineligible), entry(artwork: .candidate),
                           entry(artwork: .placeholder), entry(review: .fixtureApproved)]
        for entry in entries {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = store([entry], directory: directory)
            XCTAssertTrue(store.admittedEntries().isEmpty)
            XCTAssertNil(store.article(for: entry))
            XCTAssertFalse(store.award(entry, on: Date(), confidence: .canDo))
        }
    }

    @MainActor func testWrongCountryAndGeneralJurisdictionDoNotAdmit() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = try entry(countries: ["US"])
        let store = store([entry], directory: directory, country: "NL")
        XCTAssertTrue(store.admittedEntries().isEmpty)
        XCTAssertFalse(store.award(entry, on: Date(), confidence: .canDo))
    }

    @MainActor func testUnknownGuideChangedBodyAndChangedRevisionDeny() throws {
        for entry in try [entry(guide: "unknown-guide"), entry(revision: "old-v0"), entry(digest: String(repeating: "a", count: 64))] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = store([entry], directory: directory)
            XCTAssertTrue(store.admittedEntries().isEmpty)
            XCTAssertFalse(store.award(entry, on: Date(), confidence: .canDo))
        }
        let original = try entry()
        let changed = catalog(body: "A different exact body with the same revision.")
        XCTAssertFalse(manifest([original]).admits(original, catalog: changed, countryCode: "US", instructionalAssets: [:], reviewFixture: false))
    }

    @MainActor func testInstructionalAssetsRequireExactVerifiedBindings() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let digest = String(repeating: "a", count: 64)
        let entry = try entry(assets: ["sort": digest])
        XCTAssertTrue(store([entry], directory: directory).admittedEntries().isEmpty)
        let matching = store([entry], directory: directory, assets: ["sort-socks": ["sort": digest]])
        XCTAssertEqual(matching.admittedEntries(), [entry])
        XCTAssertTrue(matching.award(entry, on: Date(), confidence: .canDo))
        XCTAssertTrue(store([entry], directory: directory, assets: ["sort-socks": ["sort": digest, "put-away": digest]]).admittedEntries().isEmpty)
        let badSlot = try self.entry(assets: ["unknown-step": digest])
        XCTAssertTrue(store([badSlot], directory: directory, assets: ["sort-socks": ["unknown-step": digest]]).admittedEntries().isEmpty)
    }

    @MainActor func testHigherRiskRequiresPreparedBadge() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(store([try entry(risk: .higher)], directory: directory).admittedEntries().isEmpty)
        XCTAssertEqual(store([try entry(risk: .higher, kind: .prepared)], directory: directory).admittedEntries().count, 1)
    }

    func testManifestRejectsBrokenCanonicalMappingsAndWorldReferences() throws {
        let first = try entry()
        XCTAssertThrowsError(try manifest([first, entry(badge: "another-badge", skill: first.canonicalSkillID, guide: "other-guide")]).validate())
        XCTAssertThrowsError(try manifest([first, entry(skill: "different-skill", guide: "other-guide")]).validate())
        XCTAssertThrowsError(try manifest([first, first]).validate())
        XCTAssertThrowsError(try manifest([entry(worlds: ["missing-world"])]).validate())
        XCTAssertThrowsError(try manifest([entry(countries: ["General"])]).validate())
        XCTAssertThrowsError(try PassportManifest.decode(Data("{\"schemaVersion\":99}".utf8)))
    }

    @MainActor func testCrossWorldRepeatedAwardPreservesSingleIdentityAndDate() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = try entry(worlds: ["home", "workshop"])
        let store = store([entry], directory: directory)
        XCTAssertEqual(store.worlds().count, 2)
        let date = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(store.award(entry, on: date, confidence: .canDo))
        let first = try XCTUnwrap(store.achievements.first)
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .practicing))
        XCTAssertEqual(store.achievements, [first])
        XCTAssertEqual(first.chosenDate, date)
        XCTAssertTrue(first.selfReported)
    }

    @MainActor func testUndoRefresherVisibilityAndRestoreRemainIndependent() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = try entry()
        let store = store([entry], directory: directory)
        XCTAssertTrue(store.setActivity(.trying, for: entry.guideID))
        XCTAssertTrue(store.award(entry, on: Date(timeIntervalSince1970: 1_000), confidence: .canDo))
        let first = try XCTUnwrap(store.achievements.first)
        XCTAssertTrue(store.setConfidence(.refresher, for: entry.canonicalBadgeID))
        XCTAssertTrue(store.setSashVisibility(false, for: entry.canonicalBadgeID))
        XCTAssertEqual(store.achievements.first?.status, .earned)
        XCTAssertTrue(store.removeAchievement(entry.canonicalBadgeID))
        XCTAssertEqual(store.activity(for: entry.guideID), .trying)
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .canDo))
        let restored = try XCTUnwrap(store.achievements.first)
        XCTAssertEqual(restored.id, first.id)
        XCTAssertEqual(restored.chosenDate, first.chosenDate)
        XCTAssertEqual(restored.entry, first.entry)
        XCTAssertEqual(restored.confidence, .refresher)
        XCTAssertFalse(restored.visibleOnSash)
        XCTAssertTrue(store.setActivity(nil, for: entry.guideID))
        let reloaded = self.store([entry], directory: directory)
        XCTAssertEqual(reloaded.achievements, store.achievements)
        XCTAssertNil(reloaded.activity(for: entry.guideID))
    }

    @MainActor func testWithdrawnManifestRetainsHistoryAndBlocksRestoration() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = try entry()
        let store = store([entry], directory: directory)
        XCTAssertTrue(store.setActivity(.trying, for: entry.guideID))
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .canDo))
        let historical = try XCTUnwrap(store.achievements.first)
        let withdrawn = try self.entry(publication: .withdrawn)
        let current = self.store([withdrawn], directory: directory)
        XCTAssertEqual(current.achievements.first, historical)
        XCTAssertFalse(current.isCurrent(historical))
        XCTAssertTrue(current.removeAchievement(entry.canonicalBadgeID))
        XCTAssertFalse(current.award(withdrawn, on: Date(), confidence: .canDo))
        XCTAssertEqual(current.achievements.first?.status, .removed)
        XCTAssertTrue(current.setConfidence(.refresher, for: entry.canonicalBadgeID))
        XCTAssertTrue(current.setActivity(nil, for: entry.guideID))
        XCTAssertNil(current.activity(for: entry.guideID))
    }

    @MainActor func testChangedCatalogRetainsOriginalSnapshot() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = try entry()
        let store = store([entry], directory: directory)
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .canDo))
        let historical = try XCTUnwrap(store.achievements.first)
        let changed = catalog(revision: "test-v2", body: "Updated sock instruction.")
        let currentEntry = try self.entry(catalog: changed)
        let current = self.store([currentEntry], directory: directory, catalog: changed)
        XCTAssertEqual(current.achievements, [historical])
        XCTAssertFalse(current.isCurrent(historical))
        XCTAssertTrue(current.award(currentEntry, on: Date(), confidence: .canDo))
        XCTAssertEqual(current.achievements, [historical])
    }

    @MainActor func testLegacyLibraryBytesAreUntouched() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var library = UserLibrary()
        var progress = ArticleProgress()
        progress.isSaved = true
        progress.rating = 5
        progress.personalNotes = "Private old notes"
        progress.reminderDate = Date(timeIntervalSince1970: 1_000)
        progress.checkedSteps["sort"] = catalog().articles[0].steps[0].fingerprint
        library.articles["sort-socks"] = progress
        let bytes = try JSONEncoder().encode(library)
        let legacy = directory.appendingPathComponent("UserLibrary-v1.json")
        try bytes.write(to: legacy)
        let entry = try entry()
        let store = store([entry], directory: directory)
        XCTAssertTrue(store.setActivity(.learning, for: entry.guideID))
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .practicing))
        XCTAssertTrue(store.removeAchievement(entry.canonicalBadgeID))
        XCTAssertEqual(try Data(contentsOf: legacy), bytes)
        XCTAssertEqual(try UserLibrary.decode(Data(contentsOf: legacy)), library)
    }

    @MainActor func testCorruptAndUnsupportedPassportPreserveBytesAndBlockWrites() throws {
        for bytes in [Data("private recovery evidence".utf8), Data("{\"schemaVersion\":99,\"activities\":{},\"achievements\":{}}".utf8)] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("SkillPassport-v1.json")
            try bytes.write(to: url)
            let entry = try entry()
            let store = store([entry], directory: directory)
            XCTAssertFalse(store.canSave)
            XCTAssertNotNil(store.storageIssue)
            XCTAssertFalse(store.award(entry, on: Date(), confidence: .canDo))
            XCTAssertFalse(store.setActivity(.trying, for: entry.guideID))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    @MainActor func testFailedWriteLeavesMemoryUnchangedAndRetryAwardsOnce() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("directory blocker".utf8).write(to: directory)
        let entry = try entry()
        let store = store([entry], directory: directory)
        XCTAssertTrue(store.canSave)
        XCTAssertFalse(store.award(entry, on: Date(), confidence: .canDo))
        XCTAssertTrue(store.achievements.isEmpty)
        XCTAssertEqual(try Data(contentsOf: directory), Data("directory blocker".utf8))
        try FileManager.default.removeItem(at: directory)
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .canDo))
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .canDo))
        XCTAssertEqual(store.achievements.count, 1)
        XCTAssertNil(store.actionIssue)
    }

    @MainActor func testFailedChangePreservesPreviousFileAndAchievement() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = try entry()
        let store = store([entry], directory: directory)
        XCTAssertTrue(store.award(entry, on: Date(), confidence: .canDo))
        let original = store.achievements
        let url = directory.appendingPathComponent("SkillPassport-v1.json")
        let bytes = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertFalse(store.removeAchievement(entry.canonicalBadgeID))
        XCTAssertEqual(store.achievements, original)
        try FileManager.default.removeItem(at: url)
        try bytes.write(to: url)
        XCTAssertEqual(self.store([entry], directory: directory).achievements, original)
    }

    @MainActor func testReviewFixtureRequiresBothExplicitDebugGates() throws {
        let entry = try entry(review: .fixtureApproved, artwork: .placeholder)
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(store([entry], directory: directory, fixture: true).admittedEntries().isEmpty)
        XCTAssertTrue(store([entry], directory: directory, requestedFixture: true).admittedEntries().isEmpty)
        let isolated = store([entry], directory: directory, fixture: true, requestedFixture: true)
        #if DEBUG
        XCTAssertEqual(isolated.admittedEntries(), [entry])
        #else
        XCTAssertTrue(isolated.admittedEntries().isEmpty)
        #endif
        let candidate = try self.entry(review: .fixtureApproved, artwork: .candidate)
        XCTAssertTrue(store([candidate], directory: directory, fixture: true, requestedFixture: true).admittedEntries().isEmpty)
    }

    @MainActor func testLargeImmutableAdmissionSupportsRepeatedRowsAndRejectsChangedEntry() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let seed = catalog()
        let original = seed.articles[0]
        let articles = (0..<2_000).map { index in
            AdultArticle(id: "guide-\(index)", title: original.title, summary: original.summary,
                categoryID: original.categoryID, symbol: original.symbol, minutes: original.minutes,
                jurisdiction: original.jurisdiction, updatedAt: original.updatedAt, tags: original.tags, tools: original.tools,
                steps: original.steps, cautions: original.cautions, sources: original.sources)
        }
        let catalog = AdultCatalog(schemaVersion: seed.schemaVersion, revision: seed.revision,
            publishedAt: seed.publishedAt, categories: seed.categories, articles: articles)
        try catalog.validate()
        let entries = try articles.enumerated().map { index, article in
            let single = AdultCatalog(schemaVersion: seed.schemaVersion, revision: seed.revision,
                publishedAt: seed.publishedAt, categories: seed.categories, articles: [article])
            return try entry(catalog: single, badge: "badge-\(index)", skill: "skill-\(index)", guide: article.id)
        }
        let store = store(entries, directory: directory, catalog: catalog)
        XCTAssertEqual(store.admittedEntries(), entries)
        for _ in 0..<3 {
            for entry in entries { XCTAssertEqual(store.article(for: entry)?.id, entry.guideID) }
        }
        let target = entries[1_999]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(target)) as? [String: Any])
        object["criterion"] = "An unapproved replacement criterion."
        let changed = try JSONDecoder().decode(PassportEntry.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(changed.id, target.id)
        XCTAssertNil(store.article(for: changed))
        XCTAssertFalse(store.award(changed, on: Date(), confidence: .canDo))
        XCTAssertTrue(store.award(target, on: Date(), confidence: .canDo))
        XCTAssertEqual(store.achievements.first?.entry, target)
    }
}

#if DEBUG
final class AdultPassportReviewIntegrationTests: XCTestCase {
    @MainActor func testReviewSessionAcceptsOnlyPinnedUnchangedGuideInCurrentCatalog() throws {
        let session = try AdultPassportReviewSession(id: UUID())
        XCTAssertFalse(session.passport.admittedEntries().isEmpty)
        XCTAssertTrue(session.assistant.isPrivateQA)
    }
}
#endif
