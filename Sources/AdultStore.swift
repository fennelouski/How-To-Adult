import Foundation
import Observation
import UserNotifications
import CoreGraphics

@MainActor @Observable
final class AdultStore {
    private(set) var catalog: AdultCatalog?
    private(set) var illustrations: AdultIllustrations?
    private(set) var library = UserLibrary()
    private(set) var isRefreshing = false
    private(set) var isScheduling = false
    private(set) var storageIssue: String?
    private(set) var updateIssue: String?
    var actionIssue: String?
    var requestedGuideID: String?
    var requestedAssistantActionID: UUID?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let bundledURL: URL?
    @ObservationIgnored private let remoteURL: URL?
    @ObservationIgnored private let illustrationDownload: @Sendable (URL) async throws -> Data
    @ObservationIgnored private var illustrationRequests = Set<String>()
    @ObservationIgnored private let notifications = UNUserNotificationCenter.current()
    @ObservationIgnored private var notificationRouter: AdultNotificationRouter?
    @ObservationIgnored private var loadedLibrary = false
    @ObservationIgnored private let allowsNotifications: Bool
    @ObservationIgnored private let allowsCatalogRefresh: Bool

    init(directory: URL? = nil, bundledURL: URL? = Bundle.main.url(forResource: "catalog", withExtension: "json"), remoteURL: URL? = nil,
         allowsRemoteUpdates: Bool = true, allowsNotifications: Bool = true, allowsArtworkReads: Bool = false, illustrationDownload: (@Sendable (URL) async throws -> Data)? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HowToAdult", isDirectory: true)
        self.bundledURL = bundledURL
        let configured = (Bundle.main.object(forInfoDictionaryKey: "AdultCatalogURL") as? String).flatMap(URL.init(string:))
        self.remoteURL = allowsRemoteUpdates || allowsArtworkReads ? (remoteURL ?? configured) : nil
        self.allowsCatalogRefresh = allowsRemoteUpdates
        #if DEBUG
        self.allowsNotifications = allowsNotifications && ProcessInfo.processInfo.environment["ADULT_QA_BLANK_HOST"] != "1"
        #else
        self.allowsNotifications = allowsNotifications
        #endif
        self.illustrationDownload = illustrationDownload ?? { url in
            try await Self.downloadJSON(url, maximumBytes: AdultIllustrations.maximumBytes)
        }
        reloadLocalFiles()
    }

    var articles: [AdultArticle] { catalog?.articles ?? [] }
    var categories: [GuideCategory] { catalog?.categories ?? [] }
    var canSave: Bool { loadedLibrary }
    var canRefresh: Bool { allowsCatalogRefresh && remoteURL?.scheme == "https" && remoteURL?.host != nil }
    var upcoming: [AdultArticle] {
        articles.filter { (progress($0.id).reminderDate ?? .distantPast) > Date() }
            .sorted { (progress($0.id).reminderDate ?? .distantFuture) < (progress($1.id).reminderDate ?? .distantFuture) }
    }

    func article(_ id: String) -> AdultArticle? { articles.first { $0.id == id } }
    func category(_ article: AdultArticle) -> GuideCategory? { categories.first { $0.id == article.categoryID } }
    func progress(_ id: String) -> ArticleProgress { library.articles[id] ?? ArticleProgress() }

    func illustration(guideID: String, stepID: String = "") -> GuideIllustration? {
        guard illustrations?.revision == catalog?.revision else { return nil }
        return illustrations?.illustration(guideID: guideID, stepID: stepID)
    }

    func illustrationURL(_ illustration: GuideIllustration) -> URL? {
        guard let remoteURL else { return nil }
        return AdultIllustrations.assetURL(catalogURL: remoteURL, digest: illustration.assetSHA256)
    }

    func reloadLocalFiles() {
        do {
            let saved = directory.appendingPathComponent("UserLibrary-v1.json")
            library = FileManager.default.fileExists(atPath: saved.path) ? try UserLibrary.decode(Data(contentsOf: saved)) : UserLibrary()
            loadedLibrary = true
            storageIssue = nil
        } catch {
            loadedLibrary = false
            storageIssue = "Your saved guides could not be opened. The original file is preserved. Check available storage, then retry."
        }
        var bundledCatalog: AdultCatalog?
        if let bundledURL {
            do { bundledCatalog = try AdultCatalog.decode(Data(contentsOf: bundledURL)) }
            catch { updateIssue = "The included library could not be opened. Try checking for a library update." }
        }
        let cache = directory.appendingPathComponent("catalog-cache-v1.json")
        if FileManager.default.fileExists(atPath: cache.path) {
            do {
                let cached = try AdultCatalog.decode(Data(contentsOf: cache))
                // An app update may include a newer library than the last online publication.
                catalog = (cached.publicationDate ?? .distantPast) >= (bundledCatalog?.publicationDate ?? .distantPast) ? cached : bundledCatalog
            } catch {
                catalog = bundledCatalog
                updateIssue = "The downloaded library could not be opened. Your included guides are still available."
            }
        } else { catalog = bundledCatalog }
        reloadIllustrations()
    }

    func refreshIllustrations() async {
        guard let snapshot = catalog, illustrations?.revision != snapshot.revision,
              !illustrationRequests.contains(snapshot.revision),
              let remoteURL,
              let url = AdultIllustrations.manifestURL(catalogURL: remoteURL, revision: snapshot.revision) else { return }
        illustrationRequests.insert(snapshot.revision)
        defer { illustrationRequests.remove(snapshot.revision) }
        do {
            let data = try await illustrationDownload(url)
            _ = try AdultIllustrations.decode(data, for: snapshot)
            try Task.checkCancellation()
            // Navigation/refresh may select a newer catalog while this request is running.
            guard catalog?.revision == snapshot.revision else { return }
            // Artwork must never block the readable guide, including when storage is full.
            try adoptIllustrations(data, for: snapshot)
        } catch {
            // Older catalogs may have no sidecar. Offline/invalid artwork is optional.
        }
    }

    func toggleSaved(_ id: String) {
        guard article(id) != nil else { return }
        var next = library
        var progress = progress(id)
        progress.isSaved.toggle()
        next.articles[id] = progress
        commit(next)
    }

    func toggleStep(_ step: GuideStep, in article: AdultArticle) {
        guard self.article(article.id)?.steps.contains(step) == true else { return }
        var next = library
        var progress = progress(article.id)
        if progress.isChecked(step) { progress.checkedSteps.removeValue(forKey: step.id) }
        else { progress.checkedSteps[step.id] = step.fingerprint }
        next.articles[article.id] = progress
        commit(next)
    }

    @discardableResult func saveNotes(_ notes: String, for id: String, expectedNotes: String? = nil) -> Bool {
        guard article(id) != nil, notes.count <= 50_000 else { actionIssue = "Keep your notes under 50,000 characters. Your earlier notes are unchanged."; return false }
        if let expectedNotes, (progress(id).personalNotes ?? "") != expectedNotes { actionIssue = "These notes changed in another window. Your draft is still here; copy it before reopening the latest notes."; return false }
        var next = library
        var progress = progress(id)
        progress.personalNotes = notes.isEmpty ? nil : notes
        next.articles[id] = progress
        return commit(next)
    }

    func rate(_ id: String, stars: Int?) {
        guard article(id) != nil, stars.map({ (1...5).contains($0) }) ?? true else { return }
        var next = library
        var progress = progress(id)
        progress.rating = stars
        next.articles[id] = progress
        commit(next)
    }

    @discardableResult private func commit(_ next: UserLibrary) -> Bool {
        guard loadedLibrary else { actionIssue = storageIssue; return false }
        do {
            let data = try JSONEncoder().encode(next)
            _ = try UserLibrary.decode(data)
            try write(data, to: directory.appendingPathComponent("UserLibrary-v1.json"))
            library = next
            return true
        } catch {
            actionIssue = "This change could not be saved. Your earlier progress is safe. Check available storage and try again."
            return false
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    func refresh() async {
        guard !isRefreshing, canRefresh, let remoteURL else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let (data, newCatalog) = try await Self.download(remoteURL)
            guard (newCatalog.publicationDate ?? .distantPast) >= (catalog?.publicationDate ?? .distantPast) else {
                throw CatalogError.invalid
            }
            try write(data, to: directory.appendingPathComponent("catalog-cache-v1.json"))
            catalog = newCatalog
            reloadIllustrations()
            updateIssue = nil
            await reconcileNotifications()
        } catch {
            updateIssue = "Couldn’t update the library. Your saved progress and available guides are safe. Try again when you’re online."
        }
        await refreshIllustrations()
    }

    nonisolated private static func download(_ url: URL) async throws -> (Data, AdultCatalog) {
        let data = try await downloadJSON(url, maximumBytes: AdultCatalog.maximumBytes)
        return (data, try AdultCatalog.decode(data))
    }

    nonisolated private static func downloadJSON(_ url: URL, maximumBytes: Int) async throws -> Data {
        guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw CatalogError.invalid }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url == url, response.expectedContentLength <= Int64(maximumBytes) else { throw CatalogError.unavailable }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw CatalogError.tooLarge }
            data.append(byte)
        }
        return data
    }


    // Only the configured catalog service supplies artwork; manifests cannot nominate URLs.
    private var illustrationService: URL? {
        guard let remoteURL, remoteURL.scheme == "https", remoteURL.host != nil,
              remoteURL.user == nil, remoteURL.password == nil, remoteURL.query == nil,
              remoteURL.fragment == nil, remoteURL.path == "/v1/catalog" else { return nil }
        return remoteURL.deletingLastPathComponent()
    }

    func illustration(for article: AdultArticle, stepID: String = "") -> GuideIllustration? {
        guard self.article(article.id) == article, illustrations?.revision == catalog?.revision else { return nil }
        return illustrations?.items.first { $0.guideID == article.id && $0.stepID == stepID }
    }

    private func reloadIllustrations() {
        illustrations = nil
        guard let catalog, let service = illustrationService,
              let fingerprint = try? GuideIllustrationManifest.catalogFingerprint(catalog),
              let data = try? Self.cachedData(directory.appendingPathComponent("illustrations-cache-v1.json"), maximumBytes: GuideIllustrationManifest.maximumBytes + 1_024),
              let cached = try? JSONDecoder().decode(CachedIllustrations.self, from: data),
              cached.schemaVersion == 1, cached.service == service.absoluteString,
              cached.catalogFingerprint == fingerprint,
              (try? cached.manifest.validate(for: catalog)) != nil else { return }
        illustrations = cached.manifest
    }

    func adoptIllustrations(_ data: Data, for expectedCatalog: AdultCatalog) throws {
        guard let catalog, let service = illustrationService,
              try GuideIllustrationManifest.catalogFingerprint(catalog) == GuideIllustrationManifest.catalogFingerprint(expectedCatalog) else { throw CatalogError.invalid }
        let manifest = try GuideIllustrationManifest.decode(data, for: catalog)
        let cached = CachedIllustrations(schemaVersion: 1, service: service.absoluteString,
                                         catalogFingerprint: try GuideIllustrationManifest.catalogFingerprint(catalog), manifest: manifest)
        let encoded = try JSONEncoder().encode(cached)
        guard encoded.count <= GuideIllustrationManifest.maximumBytes + 1_024 else { throw CatalogError.tooLarge }
        try write(encoded, to: directory.appendingPathComponent("illustrations-cache-v1.json"))
        illustrations = manifest
    }

    private func isCurrentIllustration(_ item: GuideIllustration, revision: String) -> Bool {
        catalog?.revision == revision && illustrations?.revision == revision && illustrations?.items.contains(item) == true
    }

    func cachedIllustrationImage(_ item: GuideIllustration, revision: String) -> CGImage? {
        guard isCurrentIllustration(item, revision: revision),
              let data = try? Self.cachedData(imageURL(item), maximumBytes: GuideIllustration.maximumImageBytes) else { return nil }
        return try? GuideIllustration.image(data, expectedDigest: item.assetSHA256)
    }

    func cacheIllustrationImage(_ data: Data, for item: GuideIllustration, revision: String) -> CGImage? {
        guard isCurrentIllustration(item, revision: revision),
              let image = try? GuideIllustration.image(data, expectedDigest: item.assetSHA256) else { return nil }
        let url = imageURL(item)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
            let used = files.filter { $0 != url }.reduce(0) { total, file in
                let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                return total + (values?.isRegularFile == true ? (values?.fileSize ?? 0) : 0)
            }
            // ponytail: 32 MB cache ceiling with no eviction; add LRU only if needed for offline artwork.
            if used + data.count <= 32 * 1_024 * 1_024 { try write(data, to: url) }
        } catch { /* A storage failure can omit artwork, never overwrite personal progress. */ }
        return image
    }

    func illustrationImage(_ item: GuideIllustration, revision: String) async -> CGImage? {
        guard isCurrentIllustration(item, revision: revision) else { return nil }
        if let image = cachedIllustrationImage(item, revision: revision) { return image }
        guard let service = illustrationService else { return nil }
        do {
            let url = service.appendingPathComponent("assets").appendingPathComponent(item.assetSHA256)
            let data = try await Self.downloadIllustrationResource(url, type: "image/png", maximumBytes: GuideIllustration.maximumImageBytes)
            try Task.checkCancellation()
            return cacheIllustrationImage(data, for: item, revision: revision)
        } catch { return nil }
    }

    private func imageURL(_ item: GuideIllustration) -> URL {
        directory.appendingPathComponent("illustration-assets-v1", isDirectory: true).appendingPathComponent(item.assetSHA256 + ".png")
    }

    nonisolated private static func cachedData(_ url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= maximumBytes else { throw CatalogError.tooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else { throw CatalogError.tooLarge }
        return data
    }

    nonisolated private static func downloadIllustrationResource(_ url: URL, type: String, maximumBytes: Int) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue(type, forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, response.url == url,
              http.mimeType?.lowercased() == type, response.expectedContentLength <= Int64(maximumBytes) else { throw CatalogError.unavailable }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw CatalogError.tooLarge }
            data.append(byte)
        }
        return data
    }

    func installNotificationRouting() {
        guard allowsNotifications else { return }
        if notificationRouter == nil {
            let router = AdultNotificationRouter(store: self)
            notificationRouter = router
            notifications.delegate = router
        }
    }

    func activateNotifications() async {
        guard allowsNotifications else { return }
        installNotificationRouting()
        await reconcileNotifications()
    }

    private func reconcileNotifications() async {
        guard loadedLibrary, allowsNotifications else { return }
        let settings = await notifications.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            let liveIDs = Set(upcoming.map { notificationID($0.id) })
            let pending = await notifications.pendingNotificationRequests()
            let orphanIDs = pending.map(\.identifier).filter { $0.hasPrefix("AdultGuide.") && !liveIDs.contains($0) }
            notifications.removePendingNotificationRequests(withIdentifiers: orphanIDs)
            // Repair a previous process interruption between the file write and notification scheduling.
            let otherCount = pending.filter { !$0.identifier.hasPrefix("AdultGuide.") }.count
            let capacity = max(0, min(40, 60 - otherCount))
            for planned in upcoming.prefix(capacity) {
                guard let article = self.article(planned.id), let date = progress(planned.id).reminderDate, date > Date() else { continue }
                do {
                    try await AdultNotificationBudget.add(request(for: article, date: date, sound: progress(article.id).reminderSound))
                    if self.article(article.id) == nil || progress(article.id).reminderDate == nil {
                        notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(article.id)])
                    }
                }
                catch { actionIssue = "A saved reminder could not be scheduled. Open Reminders to try again." }
            }
        }
    }

    func schedule(_ article: AdultArticle, date: Date, sound: Bool) async -> Bool {
        guard allowsNotifications else { return false }
        guard canSave, !isScheduling, self.article(article.id) != nil else { return false }
        guard date.timeIntervalSinceNow >= 60 else {
            actionIssue = "Choose a reminder at least one minute from now."
            return false
        }
        guard (progress(article.id).reminderDate ?? .distantPast) > Date() || upcoming.count < 40 else {
            actionIssue = "You can keep up to 40 upcoming reminders. Remove one before adding another."
            return false
        }
        isScheduling = true
        defer { isScheduling = false }
        do {
            guard try await notifications.requestAuthorization(options: [.alert, .sound]) else {
                actionIssue = "Notifications are turned off. Enable How to Adult notifications in system Settings, then try again."
                return false
            }
            guard let currentArticle = self.article(article.id) else {
                actionIssue = "This guide changed while you were choosing a reminder. Choose a guide from the current library."
                return false
            }
            guard date.timeIntervalSinceNow >= 60 else {
                actionIssue = "Choose a reminder at least one minute from now."
                return false
            }
            let oldProgress = progress(article.id)
            try await AdultNotificationBudget.add(request(for: currentArticle, date: date, sound: sound))
            guard self.article(article.id) != nil else {
                notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(article.id)])
                actionIssue = "This guide is no longer in the current library. Choose another guide."
                return false
            }
            var next = library
            var updated = progress(article.id)
            updated.reminderDate = date
            updated.reminderSound = sound
            next.articles[article.id] = updated
            if !commit(next) {
                notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(article.id)])
                if let previous = oldProgress.reminderDate, previous > Date() {
                    try await AdultNotificationBudget.add(request(for: article, date: previous, sound: oldProgress.reminderSound))
                }
                return false
            }
            await reconcileNotifications()
            guard self.article(article.id) != nil else {
                notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(article.id)])
                actionIssue = "This guide is no longer in the current library. Choose another guide."
                return false
            }
            return true
        } catch {
            actionIssue = "The reminder could not be scheduled. Your guide and progress are safe. Try again."
            return false
        }
    }

    @discardableResult func cancelReminder(_ id: String) -> Bool {
        var next = library
        var updated = progress(id)
        updated.reminderDate = nil
        next.articles[id] = updated
        guard commit(next) else { return false }
        if allowsNotifications {
            notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(id)])
            notifications.removeDeliveredNotifications(withIdentifiers: [notificationID(id)])
        }
        return true
    }

    private func notificationID(_ id: String) -> String { "AdultGuide." + id }
    private func request(for article: AdultArticle, date: Date, sound: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = article.title
        content.body = "Your guide is ready when you are."
        content.userInfo = ["guideID": article.id]
        if sound { content.sound = .default }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(identifier: notificationID(article.id), content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }

    func openGuide(_ id: String) {
        guard article(id) != nil else { return }
        requestedGuideID = id
    }
}


private struct CachedIllustrations: Codable {
    let schemaVersion: Int
    let service: String
    let catalogFingerprint: String
    let manifest: GuideIllustrationManifest
}

private final class AdultNotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private weak var store: AdultStore?
    @MainActor init(store: AdultStore) { self.store = store }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let id = info["guideID"] as? String {
            await MainActor.run { self.store?.openGuide(id) }
        } else if let raw = info["assistantActionID"] as? String, let id = UUID(uuidString: raw) {
            await MainActor.run { self.store?.requestedAssistantActionID = id }
        }
    }
}
