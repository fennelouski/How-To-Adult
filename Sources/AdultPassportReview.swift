#if DEBUG
import SwiftUI

// This launch-only review session never opens the owner's library or provider credentials.
@MainActor
struct AdultPassportReviewSession {
    let guides: AdultStore
    let assistant: AdultAssistantController
    let passport: AdultPassportStore
    let preferences: UserDefaults

    init(id: UUID) throws {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("HowToAdult-PassportReview/" + id.uuidString, isDirectory: true)
        let guides = AdultStore(directory: directory, allowsRemoteUpdates: false, allowsNotifications: false)
        guard let catalog = guides.catalog,
              let article = catalog.articles.first(where: { $0.id == "read-a-care-label" }),
              try PassportManifest.articleFingerprint(article) == "1495a2108198a77a90c76cd90f92e08d137184a0f3bdbcc0a1ff06fb101708e1" else { throw CatalogError.invalid }
        let worlds = [
            PassportWorld(id: "home-base", title: "Home Base", symbol: "house", colorKey: "green"),
            PassportWorld(id: "workshop-woods", title: "Workshop Woods", symbol: "leaf", colorKey: "orange")
        ]
        let entry = PassportEntry(canonicalBadgeID: "qa-care-label-badge", canonicalSkillID: "qa-read-care-instruction",
            guideID: article.id, catalogRevision: catalog.revision, bodySHA256: try PassportManifest.articleFingerprint(article),
            instructionalAssets: [:], badgeAssetVersion: "qa-neutral-shape-v1", worldIDs: worlds.map(\.id),
            task: "Find one care instruction on a garment you already own. If a symbol is unclear, check the maker’s guide. Stop there; this task does not involve washing, ironing or treating the garment.",
            outcome: "I can find a garment’s care instruction.",
            criterion: "I found one care instruction and checked the maker’s guide if a symbol was unclear.",
            warnings: ["The garment label takes priority over a general laundry tip.", "An unclear symbol is a reason to ask or look it up, not guess."],
            reviewedCountryCodes: ["US"], review: .fixtureApproved, publication: .published, award: .eligible,
            artwork: .placeholder, risk: .low, badgeKind: .skill)
        let manifest = PassportManifest(version: "qa-passport-20261008-v1", worlds: worlds, entries: [entry], reviewFixture: true)
        try manifest.validate()
        self.guides = guides
        self.passport = AdultPassportStore(directory: directory, manifest: manifest, catalog: catalog, countryCode: "US", reviewFixture: true)
        let preferences = UserDefaults(suiteName: "com.nathanfennel.How-To-Adult.PassportReview." + id.uuidString)!
        self.preferences = preferences
        self.assistant = AdultAssistantController(library: AdultAssistantLibrary(directory: directory),
            connection: AdultAIConnection(preferences: preferences, isPrivateQA: true), isPrivateQA: true, privateSessionID: id)
    }
}
#endif
