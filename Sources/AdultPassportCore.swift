import Foundation
import CryptoKit

struct PassportWorld: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let colorKey: String
}

enum PassportBadgeKind: String, Codable, Sendable { case skill, prepared }
enum PassportReviewState: String, Codable, Sendable { case unreviewed, approved, held, fixtureApproved }
enum PassportPublicationState: String, Codable, Sendable { case unpublished, published, withdrawn }
enum PassportAwardState: String, Codable, Sendable { case ineligible, eligible }
enum PassportArtworkState: String, Codable, Sendable { case candidate, productionReady, placeholder }
enum PassportRisk: String, Codable, Sendable { case low, higher }
enum PassportGuideActivity: String, Codable, Sendable { case learning, trying }
enum PassportConfidence: String, Codable, CaseIterable, Sendable {
    case canDo, practicing, refresher
    var title: String {
        switch self { case .canDo: "Can do now"; case .practicing: "Practicing"; case .refresher: "Want a refresher" }
    }
}
enum PassportAchievementStatus: String, Codable, Sendable { case earned, removed }

struct PassportEntry: Codable, Hashable, Identifiable, Sendable {
    let canonicalBadgeID: String
    let canonicalSkillID: String
    let guideID: String
    let catalogRevision: String
    let bodySHA256: String
    let instructionalAssets: [String: String]
    let badgeAssetVersion: String
    let worldIDs: [String]
    let task: String
    let outcome: String
    let criterion: String
    let warnings: [String]
    let reviewedCountryCodes: [String]
    let review: PassportReviewState
    let publication: PassportPublicationState
    let award: PassportAwardState
    let artwork: PassportArtworkState
    let risk: PassportRisk
    let badgeKind: PassportBadgeKind
    var id: String { canonicalBadgeID + ":" + guideID }
}

struct PassportManifest: Codable, Sendable {
    var schemaVersion = 1
    let version: String
    let worlds: [PassportWorld]
    let entries: [PassportEntry]
    var reviewFixture = false
    static let empty = PassportManifest(version: "empty", worlds: [], entries: [])

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= AdultCatalog.maximumBytes else { throw CatalogError.tooLarge }
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        try manifest.validate()
        return manifest
    }

    static func articleFingerprint(_ article: AdultArticle) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: try encoder.encode(article)).map { String(format: "%02x", $0) }.joined()
    }

    func validate() throws {
        guard schemaVersion == 1, !version.isEmpty, version.count <= 160,
              worlds.count <= 30, entries.count <= 2_000,
              Set(worlds.map(\.id)).count == worlds.count,
              Set(entries.map(\.id)).count == entries.count else { throw CatalogError.invalid }
        let worldIDs = Set(worlds.map(\.id))
        for world in worlds {
            guard Self.validID(world.id), Self.validText(world.title, limit: 100),
                  Self.validText(world.symbol, limit: 100), Self.validText(world.colorKey, limit: 100) else { throw CatalogError.invalid }
        }
        var badgeBindings: [String: PassportEntry] = [:]
        var skillBindings: [String: String] = [:]
        for entry in entries {
            try Self.validate(entry)
            guard Set(entry.worldIDs).isSubset(of: worldIDs) else { throw CatalogError.invalid }
            if let badgeID = skillBindings[entry.canonicalSkillID], badgeID != entry.canonicalBadgeID { throw CatalogError.invalid }
            skillBindings[entry.canonicalSkillID] = entry.canonicalBadgeID
            // One canonical badge cannot silently acquire a different task or art identity.
            if let prior = badgeBindings[entry.canonicalBadgeID] {
                guard prior.canonicalSkillID == entry.canonicalSkillID,
                      prior.badgeKind == entry.badgeKind, prior.badgeAssetVersion == entry.badgeAssetVersion,
                      prior.task == entry.task, prior.outcome == entry.outcome, prior.criterion == entry.criterion,
                      prior.risk == entry.risk else { throw CatalogError.invalid }
            }
            badgeBindings[entry.canonicalBadgeID] = entry
        }
    }

    static func validate(_ entry: PassportEntry) throws {
        guard validID(entry.canonicalBadgeID), validID(entry.canonicalSkillID), validID(entry.guideID),
              validText(entry.catalogRevision, limit: 160), validDigest(entry.bodySHA256),
              validText(entry.badgeAssetVersion, limit: 160),
              !entry.worldIDs.isEmpty, entry.worldIDs.count <= 30,
              Set(entry.worldIDs).count == entry.worldIDs.count, entry.worldIDs.allSatisfy(validID),
              validText(entry.task, limit: 8_000), validText(entry.outcome, limit: 2_000),
              validText(entry.criterion, limit: 4_000), entry.warnings.count <= 80,
              entry.warnings.allSatisfy({ validText($0, limit: 4_000) }),
              !entry.reviewedCountryCodes.isEmpty, entry.reviewedCountryCodes.count <= 250,
              Set(entry.reviewedCountryCodes).count == entry.reviewedCountryCodes.count,
              entry.reviewedCountryCodes.allSatisfy({ $0.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil }),
              entry.instructionalAssets.count <= 81,
              entry.instructionalAssets.allSatisfy({ ($0.key.isEmpty || validID($0.key)) && validDigest($0.value) }) else { throw CatalogError.invalid }
    }

    func admits(_ entry: PassportEntry, catalog: AdultCatalog, countryCode: String,
                instructionalAssets: [String: [String: String]], reviewFixture requestedFixture: Bool) -> Bool {
        guard (try? validate()) != nil, entries.contains(entry) else { return false }
        return admitsValidated(entry, catalog: catalog, countryCode: countryCode,
                               instructionalAssets: instructionalAssets, reviewFixture: requestedFixture)
    }

    func admittedEntries(catalog: AdultCatalog, countryCode: String,
                         instructionalAssets: [String: [String: String]], reviewFixture: Bool) -> [PassportEntry] {
        guard (try? validate()) != nil else { return [] }
        return entries.filter {
            admitsValidated($0, catalog: catalog, countryCode: countryCode,
                            instructionalAssets: instructionalAssets, reviewFixture: reviewFixture)
        }
    }

    private func admitsValidated(_ entry: PassportEntry, catalog: AdultCatalog, countryCode: String,
                                instructionalAssets: [String: [String: String]], reviewFixture requestedFixture: Bool) -> Bool {
        guard entry.catalogRevision == catalog.revision,
              let article = catalog.articles.first(where: { $0.id == entry.guideID }),
              (try? Self.articleFingerprint(article)) == entry.bodySHA256,
              entry.reviewedCountryCodes.contains(countryCode),
              entry.instructionalAssets == (instructionalAssets[entry.guideID] ?? [:]),
              entry.instructionalAssets.keys.allSatisfy({ stepID in stepID.isEmpty || article.steps.contains(where: { $0.id == stepID }) }),
              entry.publication == .published, entry.award == .eligible,
              entry.risk == .low || entry.badgeKind == .prepared else { return false }
        #if DEBUG
        if reviewFixture && requestedFixture {
            return entry.review == .fixtureApproved && entry.risk == .low && entry.artwork == .placeholder
        }
        #endif
        return !reviewFixture && !requestedFixture && entry.review == .approved && entry.artwork == .productionReady
    }

    static func validID(_ value: String) -> Bool {
        value.count <= 100 && value.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil
    }
    private static func validDigest(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }
    private static func validText(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= limit &&
        !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }
    }
}

struct PassportAchievement: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let entry: PassportEntry
    let manifestVersion: String
    let guideTitle: String
    let chosenDate: Date
    let selfReported: Bool
    var status: PassportAchievementStatus
    var confidence: PassportConfidence
    var visibleOnSash: Bool
    var canonicalBadgeID: String { entry.canonicalBadgeID }
}

struct PassportState: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var activities: [String: PassportGuideActivity] = [:]
    var achievements: [String: PassportAchievement] = [:]

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= AdultCatalog.maximumBytes else { throw CatalogError.tooLarge }
        let state = try JSONDecoder().decode(Self.self, from: data)
        guard state.schemaVersion == 1, state.activities.count <= 2_000, state.achievements.count <= 2_000,
              state.activities.keys.allSatisfy(PassportManifest.validID),
              Set(state.achievements.values.map(\.id)).count == state.achievements.count,
              Set(state.achievements.values.map { $0.entry.canonicalSkillID }).count == state.achievements.count else { throw CatalogError.invalid }
        for (key, achievement) in state.achievements {
            try PassportManifest.validate(achievement.entry)
            guard key == achievement.canonicalBadgeID, achievement.selfReported,
                  !achievement.manifestVersion.isEmpty, achievement.manifestVersion.count <= 160,
                  !achievement.guideTitle.isEmpty, achievement.guideTitle.count <= 180,
                  achievement.chosenDate.timeIntervalSinceReferenceDate.isFinite else { throw CatalogError.invalid }
        }
        return state
    }
}
