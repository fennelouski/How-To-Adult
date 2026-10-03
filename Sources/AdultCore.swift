import Foundation
import CryptoKit

struct AdultCatalog: Codable, Sendable {
    let schemaVersion: Int
    let revision: String
    let publishedAt: String
    let categories: [GuideCategory]
    let articles: [AdultArticle]

    static let maximumBytes = 10 * 1_024 * 1_024
    var publicationDate: Date? { Self.parseDate(publishedAt) }

    static func decode(_ data: Data) throws -> AdultCatalog {
        guard data.count <= maximumBytes else { throw CatalogError.tooLarge }
        let catalog = try JSONDecoder().decode(AdultCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    func validate() throws {
        guard schemaVersion == 1, !revision.isEmpty, revision.count <= 160,
              publicationDate != nil,
              !categories.isEmpty, categories.count <= 30,
              !articles.isEmpty, articles.count <= 2_000 else { throw CatalogError.invalid }
        let categoryIDs = Set(categories.map(\.id))
        guard categoryIDs.count == categories.count,
              Set(articles.map(\.id)).count == articles.count else { throw CatalogError.duplicate }
        for category in categories {
            guard Self.validID(category.id), !category.title.isEmpty,
                  category.title.count <= 100, !category.symbol.isEmpty else { throw CatalogError.invalid }
        }
        for article in articles {
            guard Self.validID(article.id), categoryIDs.contains(article.categoryID),
                  !article.title.isEmpty, article.title.count <= 180,
                  !article.summary.isEmpty, article.summary.count <= 600,
                  (1...1_440).contains(article.minutes), !article.jurisdiction.isEmpty,
                  article.steps.count >= 2, article.steps.count <= 80,
                  Set(article.steps.map(\.id)).count == article.steps.count,
                  Set(article.tools).count == article.tools.count,
                  Set(article.cautions).count == article.cautions.count,
                  Set(article.sources.map(\.url)).count == article.sources.count else { throw CatalogError.invalid }
            for step in article.steps {
                guard Self.validID(step.id), !step.title.isEmpty, !step.body.isEmpty,
                      step.title.count <= 200, step.body.count <= 8_000 else { throw CatalogError.invalid }
            }
            for source in article.sources {
                guard !source.title.isEmpty, let url = URL(string: source.url),
                      url.scheme == "https", url.host != nil,
                      url.user == nil, url.password == nil else { throw CatalogError.invalid }
            }
        }
    }

    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 100 && value.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

enum CatalogError: LocalizedError {
    case invalid, duplicate, tooLarge, unavailable
    var errorDescription: String? {
        switch self {
        case .invalid: "The guide library is incomplete or uses an unsupported format."
        case .duplicate: "The guide library contains duplicate identifiers."
        case .tooLarge: "The guide library is larger than this app can safely download."
        case .unavailable: "The guide library could not be loaded."
        }
    }
}

struct GuideCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let colorKey: String
}

struct AdultArticle: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let categoryID: String
    let symbol: String
    let minutes: Int
    let jurisdiction: String
    let updatedAt: String
    let tags: [String]
    let tools: [String]
    let steps: [GuideStep]
    let cautions: [String]
    let sources: [GuideSource]

    func matches(_ query: String) -> Bool {
        let tokens = query.split(whereSeparator: \.isWhitespace)
        let haystack = ([title, summary, jurisdiction] + tags + steps.map { $0.title + " " + $0.body }).joined(separator: " ")
        return tokens.allSatisfy { haystack.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var shareText: String {
        var parts = [title, summary]
        if jurisdiction != "General" { parts.append(jurisdiction + " rules") }
        if !tools.isEmpty { parts.append("Before you start\n" + tools.joined(separator: "\n")) }
        parts.append(steps.map { $0.title + "\n" + $0.body }.joined(separator: "\n\n"))
        if !cautions.isEmpty { parts.append("Good to know\n" + cautions.joined(separator: "\n\n")) }
        if !sources.isEmpty { parts.append("Sources\n" + sources.map { $0.title + "\n" + $0.url }.joined(separator: "\n\n")) }
        parts.append("Reviewed " + updatedAt + "\nHow to Adult")
        return parts.joined(separator: "\n\n")
    }
}

struct GuideStep: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let body: String

    /// An edited instruction must be checked again, even if its identifier is unchanged.
    var fingerprint: String {
        SHA256.hash(data: Data((title + "\u{0}" + body).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct GuideSource: Codable, Hashable, Sendable {
    let title: String
    let url: String
}

struct ArticleProgress: Codable, Equatable, Sendable {
    var isSaved = false
    var checkedSteps: [String: String] = [:]
    var reminderDate: Date?
    var reminderSound = true

    func isChecked(_ step: GuideStep) -> Bool { checkedSteps[step.id] == step.fingerprint }
    func completedCount(in article: AdultArticle) -> Int { article.steps.filter(isChecked).count }
}

struct UserLibrary: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var articles: [String: ArticleProgress] = [:]

    static func decode(_ data: Data) throws -> UserLibrary {
        guard data.count <= AdultCatalog.maximumBytes else { throw CatalogError.tooLarge }
        let library = try JSONDecoder().decode(UserLibrary.self, from: data)
        guard library.schemaVersion == 1 else { throw CatalogError.invalid }
        return library
    }
}

enum AdultSection: String, CaseIterable, Identifiable {
    case browse = "Guides", saved = "Saved", reminders = "Reminders"
    var id: Self { self }
    var symbol: String {
        switch self { case .browse: "books.vertical"; case .saved: "bookmark"; case .reminders: "bell" }
    }
}
