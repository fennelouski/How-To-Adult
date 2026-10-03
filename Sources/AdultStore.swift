import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class AdultStore {
    private(set) var catalog: AdultCatalog?
    private(set) var library = UserLibrary()
    private(set) var isRefreshing = false
    private(set) var isScheduling = false
    private(set) var storageIssue: String?
    private(set) var updateIssue: String?
    var actionIssue: String?
    var requestedGuideID: String?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let bundledURL: URL?
    @ObservationIgnored private let remoteURL: URL?
    @ObservationIgnored private let notifications = UNUserNotificationCenter.current()
    @ObservationIgnored private var notificationRouter: AdultNotificationRouter?
    @ObservationIgnored private var loadedLibrary = false

    init(directory: URL? = nil, bundledURL: URL? = Bundle.main.url(forResource: "catalog", withExtension: "json"), remoteURL: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HowToAdult", isDirectory: true)
        self.bundledURL = bundledURL
        let configured = (Bundle.main.object(forInfoDictionaryKey: "AdultCatalogURL") as? String).flatMap(URL.init(string:))
        self.remoteURL = remoteURL ?? configured
        reloadLocalFiles()
    }

    var articles: [AdultArticle] { catalog?.articles ?? [] }
    var categories: [GuideCategory] { catalog?.categories ?? [] }
    var canSave: Bool { loadedLibrary }
    var canRefresh: Bool { remoteURL?.scheme == "https" && remoteURL?.host != nil }
    var upcoming: [AdultArticle] {
        articles.filter { (progress($0.id).reminderDate ?? .distantPast) > Date() }
            .sorted { (progress($0.id).reminderDate ?? .distantFuture) < (progress($1.id).reminderDate ?? .distantFuture) }
    }

    func article(_ id: String) -> AdultArticle? { articles.first { $0.id == id } }
    func category(_ article: AdultArticle) -> GuideCategory? { categories.first { $0.id == article.categoryID } }
    func progress(_ id: String) -> ArticleProgress { library.articles[id] ?? ArticleProgress() }

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

    @discardableResult private func commit(_ next: UserLibrary) -> Bool {
        guard loadedLibrary else { actionIssue = storageIssue; return false }
        do {
            try write(JSONEncoder().encode(next), to: directory.appendingPathComponent("UserLibrary-v1.json"))
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
            updateIssue = nil
            await reconcileNotifications()
        } catch {
            updateIssue = "Couldn’t update the library. Your saved progress and available guides are safe. Try again when you’re online."
        }
    }

    nonisolated private static func download(_ url: URL) async throws -> (Data, AdultCatalog) {
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
              response.url?.scheme == "https", response.expectedContentLength <= Int64(AdultCatalog.maximumBytes) else { throw CatalogError.unavailable }
        var data = Data()
        for try await byte in bytes {
            guard data.count < AdultCatalog.maximumBytes else { throw CatalogError.tooLarge }
            data.append(byte)
        }
        return (data, try AdultCatalog.decode(data))
    }

    func activateNotifications() async {
        if notificationRouter == nil {
            let router = AdultNotificationRouter(store: self)
            notificationRouter = router
            notifications.delegate = router
        }
        await reconcileNotifications()
    }

    private func reconcileNotifications() async {
        guard loadedLibrary else { return }
        let settings = await notifications.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            let liveIDs = Set(upcoming.map { notificationID($0.id) })
            let pending = await notifications.pendingNotificationRequests()
            let orphanIDs = pending.map(\.identifier).filter { $0.hasPrefix("AdultGuide.") && !liveIDs.contains($0) }
            notifications.removePendingNotificationRequests(withIdentifiers: orphanIDs)
            // Repair a previous process interruption between the file write and notification scheduling.
            for planned in upcoming {
                guard let article = self.article(planned.id), let date = progress(planned.id).reminderDate, date > Date() else { continue }
                do {
                    try await notifications.add(request(for: article, date: date, sound: progress(article.id).reminderSound))
                    if self.article(article.id) == nil || progress(article.id).reminderDate == nil {
                        notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(article.id)])
                    }
                }
                catch { actionIssue = "A saved reminder could not be scheduled. Open Reminders to try again." }
            }
        }
    }

    func schedule(_ article: AdultArticle, date: Date, sound: Bool) async -> Bool {
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
            try await notifications.add(request(for: currentArticle, date: date, sound: sound))
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
                    try await notifications.add(request(for: article, date: previous, sound: oldProgress.reminderSound))
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
        notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(id)])
        notifications.removeDeliveredNotifications(withIdentifiers: [notificationID(id)])
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

private final class AdultNotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private weak var store: AdultStore?
    @MainActor init(store: AdultStore) { self.store = store }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["guideID"] as? String else { return }
        await MainActor.run { self.store?.openGuide(id) }
    }
}
