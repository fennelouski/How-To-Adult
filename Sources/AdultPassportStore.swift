import Foundation
import Observation

@MainActor @Observable
final class AdultPassportStore {
    private(set) var state = PassportState()
    private(set) var storageIssue: String?
    var actionIssue: String?
    private(set) var canSave = false
    let manifest: PassportManifest
    let catalog: AdultCatalog
    let countryCode: String
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let eligibleEntries: [PassportEntry]
    @ObservationIgnored private let eligibleEntrySet: Set<PassportEntry>
    @ObservationIgnored private let articlesByID: [String: AdultArticle]

    init(directory: URL, manifest: PassportManifest, catalog: AdultCatalog, countryCode: String,
         reviewFixture: Bool = false, instructionalAssets: [String: [String: String]] = [:]) {
        self.directory = directory
        self.manifest = manifest
        self.catalog = catalog
        self.countryCode = countryCode
        // Admission inputs are immutable; row rendering never revalidates the whole manifest.
        let eligible = manifest.admittedEntries(catalog: catalog, countryCode: countryCode,
                                               instructionalAssets: instructionalAssets, reviewFixture: reviewFixture)
        self.eligibleEntries = eligible
        self.eligibleEntrySet = Set(eligible)
        self.articlesByID = Dictionary(catalog.articles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        reloadLocalFiles()
    }

    var achievements: [PassportAchievement] {
        state.achievements.values.sorted {
            $0.chosenDate == $1.chosenDate ? $0.canonicalBadgeID < $1.canonicalBadgeID : $0.chosenDate > $1.chosenDate
        }
    }

    func admittedEntries() -> [PassportEntry] {
        eligibleEntries
    }
    func worlds() -> [PassportWorld] {
        let visible = Set(admittedEntries().flatMap(\.worldIDs))
        return manifest.worlds.filter { visible.contains($0.id) }
    }
    func article(for entry: PassportEntry) -> AdultArticle? {
        guard isAdmitted(entry) else { return nil }
        return articlesByID[entry.guideID]
    }
    func isCurrent(_ achievement: PassportAchievement) -> Bool {
        isAdmitted(achievement.entry)
    }
    func activity(for guideID: String) -> PassportGuideActivity? { state.activities[guideID] }

    @discardableResult func setActivity(_ activity: PassportGuideActivity?, for guideID: String) -> Bool {
        guard PassportManifest.validID(guideID),
              activity == nil || admittedEntries().contains(where: { $0.guideID == guideID }) else { return denied() }
        var next = state
        next.activities[guideID] = activity
        return commit(next)
    }

    @discardableResult func award(_ entry: PassportEntry, on date: Date, confidence: PassportConfidence) -> Bool {
        guard let article = article(for: entry), date.timeIntervalSinceReferenceDate.isFinite else { return denied() }
        var next = state
        if var existing = next.achievements[entry.canonicalBadgeID] {
            if existing.status == .earned { return canSave }
            existing.status = .earned
            next.achievements[entry.canonicalBadgeID] = existing
        } else {
            next.achievements[entry.canonicalBadgeID] = PassportAchievement(id: UUID(), entry: entry,
                manifestVersion: manifest.version, guideTitle: article.title, chosenDate: date, selfReported: true,
                status: .earned, confidence: confidence, visibleOnSash: true)
        }
        return commit(next)
    }

    @discardableResult func removeAchievement(_ canonicalBadgeID: String) -> Bool {
        update(canonicalBadgeID) { $0.status = .removed }
    }
    @discardableResult func setConfidence(_ confidence: PassportConfidence, for canonicalBadgeID: String) -> Bool {
        update(canonicalBadgeID) { $0.confidence = confidence }
    }
    @discardableResult func setSashVisibility(_ visible: Bool, for canonicalBadgeID: String) -> Bool {
        update(canonicalBadgeID) { $0.visibleOnSash = visible }
    }

    func reloadLocalFiles() {
        do {
            let url = directory.appendingPathComponent("SkillPassport-v1.json")
            state = FileManager.default.fileExists(atPath: url.path) ? try PassportState.decode(Data(contentsOf: url)) : PassportState()
            canSave = true
            storageIssue = nil
        } catch {
            canSave = false
            storageIssue = "Your skill passport could not be opened. The original file is preserved. Check available storage, then retry."
        }
    }

    private func isAdmitted(_ entry: PassportEntry) -> Bool {
        eligibleEntrySet.contains(entry)
    }
    private func denied() -> Bool {
        actionIssue = "This task is not available to earn in this guide version and country."
        return false
    }
    private func update(_ canonicalBadgeID: String, mutation: (inout PassportAchievement) -> Void) -> Bool {
        guard var achievement = state.achievements[canonicalBadgeID] else { return false }
        mutation(&achievement)
        var next = state
        next.achievements[canonicalBadgeID] = achievement
        return commit(next)
    }
    private func commit(_ next: PassportState) -> Bool {
        guard canSave else { actionIssue = storageIssue; return false }
        if next == state { return true }
        do {
            let data = try JSONEncoder().encode(next)
            _ = try PassportState.decode(data)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("SkillPassport-v1.json")
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: url, options: .atomic)
            #endif
            state = next
            actionIssue = nil
            return true
        } catch {
            actionIssue = "This change could not be saved. Your earlier achievements are safe. Check available storage and try again."
            return false
        }
    }
}
