import Foundation
import Observation

// MARK: Sub-areas

/// Sub-areas are derived from guide tags in the app, so the published catalog schema stays unchanged.
/// A new guide with a matching tag joins its sub-area automatically; one that matches nothing is still listed under its topic.
struct GuideSubArea: Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let tags: Set<String>

    func contains(_ article: AdultArticle) -> Bool { !tags.isDisjoint(with: article.tags.map { $0.lowercased() }) }

    static func all(for categoryID: String) -> [GuideSubArea] {
        func area(_ id: String, _ title: String, _ symbol: String, _ tags: [String]) -> GuideSubArea {
            GuideSubArea(id: categoryID + "." + id, title: title, symbol: symbol, tags: Set(tags))
        }
        switch categoryID {
        case "home": return [area("laundry", "Laundry & clothes", "washer", ["laundry", "clothing care", "clothing repair", "hand sewing", "dryer", "lint screen"]),
                             area("cleaning", "Cleaning", "bubbles.and.sparkles", ["cleaning", "tidying", "surface care", "appliance care", "household", "routine maintenance", "household maintenance", "chores", "shared home", "household skills", "bedding"]),
                             area("safety", "Safety & energy", "bolt.shield", ["home safety", "energy", "water shutoff", "home preparation"]),
                             area("moving", "Moving & renting", "shippingbox", ["moving", "renting", "packing", "transitions"]),
                             area("setup", "Setting up", "sofa", ["tools", "decorating", "repair", "organization", "home administration", "model number", "decluttering", "donation", "room layout", "furniture"]),
                             area("plants", "Plants", "leaf", ["houseplants", "plants", "indoor gardening", "repotting"])]
        case "food": return [area("cooking", "Cooking", "frying.pan", ["cooking", "simple meals", "stovetop", "cooking basics", "basic cooking", "oven", "no cook", "breakfast", "baking", "measuring", "pasta", "bread"]),
                             area("safety", "Food safety", "thermometer.medium", ["food safety", "food storage"]),
                             area("shopping", "Shopping", "cart", ["groceries", "meal planning"]),
                             area("kitchen", "Kitchen care", "sink", ["dishwashing", "kitchen cleaning", "water bottle", "reusable bottle"])]
        case "money": return [area("budget", "Budgeting", "chart.pie", ["budget", "bills", "savings"]),
                              area("banking", "Banking", "building.columns", ["banking", "checking account", "account opening", "fees"]),
                              area("credit", "Credit & loans", "creditcard", ["credit", "loans", "auto loan", "apr", "borrowing"]),
                              area("taxes", "Taxes", "doc.text", ["taxes"]),
                              area("retirement", "Retirement", "chart.line.uptrend.xyaxis", ["401k", "retirement"]),
                              area("paperwork", "Paperwork", "folder", ["paperwork", "medical bills", "financial assistance", "eob", "debt help", "money worries"])]
        case "work": return [area("search", "Job search", "magnifyingglass", ["job search", "resume", "interview", "job applications", "cover letters", "career exploration", "job-search", "unemployment"]),
                             area("pay", "Pay & benefits", "doc.plaintext", ["paycheck", "benefits"]),
                             area("talk", "Communication", "envelope", ["email", "communication", "zoom", "video calls", "audio", "work communication", "project updates", "google meet", "screen sharing", "presenting"]),
                             area("docs", "Documents", "doc.richtext", ["google docs", "writing", "documents", "notes", "accessibility", "alt text", "links", "headings"]),
                             area("growth", "Growing at work", "chart.bar.xaxis", ["performance review", "self-assessment", "work evidence", "onboarding", "new job", "first day"])]
        case "wellbeing": return [area("move", "Movement", "figure.walk", ["exercise"]),
                                  area("rest", "Rest", "moon.zzz", ["sleep", "rest"]),
                                  area("care", "Health care", "stethoscope", ["health", "healthcare", "mental health", "appointments", "dental care", "pharmacy", "medicine labels", "repeat prescriptions", "vaccination records"]),
                                  area("personal", "Personal care", "comb", ["personal care", "brushing", "flossing"])]
        case "people": return [area("friends", "Friends", "person.2", ["friends", "friendship", "social", "community", "introductions", "conversation", "hobbies", "invitations", "checking in", "loneliness", "befriending", "community support", "celebration", "toast", "gifts"]),
                               area("talk", "Keeping in touch", "bubble.left.and.bubble.right", ["communication", "messages", "calls", "greeting cards", "gmail", "email", "group communication", "arrival directions", "clear writing"]),
                               area("relationships", "Relationships", "hand.raised", ["relationships", "adult relationships", "boundaries", "apology", "roommates", "consent", "intimacy", "grief", "caregiving"]),
                               area("hosting", "Hosting", "fork.knife.circle", ["hosting", "small groups", "meetings", "decisions"])]
        case "everyday": return [area("digital", "Digital", "laptopcomputer", ["iphone", "mac", "files", "digital basics", "chrome", "keyboard", "documents", "notes", "accessibility", "gmail", "email search", "google sheets", "spreadsheet", "backup", "time machine", "google pixel", "android", "phone settings"]),
                                 area("hobbies", "Hobbies", "paintpalette", ["hobbies", "creative practice", "drawing", "languages", "reading", "leisure"]),
                                 area("style", "Style", "tshirt", ["style", "clothes", "clothing", "getting dressed", "haircut"]),
                                 area("car", "Car", "car.side", ["car", "vehicle registration", "dmv", "car paperwork"]),
                                 area("travel", "Getting around", "tram", ["transport", "travel", "bus", "bicycle", "transport planning", "packing", "day trips"]),
                                 area("bills", "Bills", "iphone", ["phone bill", "contracts"]),
                                 area("civic", "Civic life", "building.2", ["civic duties", "voting", "civic paperwork", "library"]),
                                 area("routines", "Routines", "arrow.clockwise", ["planning", "routine", "routines", "organization"]),
                             area("errands", "Errands & mail", "envelope", ["usps", "mail", "returns", "customer service", "mail forwarding"]),
                             area("skills", "Everyday skills", "ruler", ["numeracy", "measuring", "household skills", "gift wrapping", "24-hour clock", "contact details", "phone calls"])]
        default: return []
        }
    }

    /// Only sub-areas that currently contain a guide.
    static func available(for categoryID: String, in articles: [AdultArticle]) -> [GuideSubArea] {
        let guides = articles.filter { $0.categoryID == categoryID }
        return all(for: categoryID).filter { area in guides.contains(where: area.contains) }
    }
}

// MARK: Filters

struct GuideFilter: Equatable, Sendable {
    enum Region: String, CaseIterable, Sendable { case any, general, unitedStates }
    var query = ""
    var favoritesOnly = false
    var hideKnown = false
    var quickOnly = false
    var region = Region.any

    static let quickMinutes = 10
    var isActive: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty || favoritesOnly || hideKnown || quickOnly || region != .any }

    func apply(_ articles: [AdultArticle], progress: (String) -> ArticleProgress) -> [AdultArticle] {
        articles.filter { article in
            let saved = progress(article.id)
            return (!favoritesOnly || saved.isSaved || !(saved.favoriteSteps ?? []).isEmpty)
                && (!hideKnown || !saved.isKnownGuide(article))
                && (!quickOnly || article.minutes <= Self.quickMinutes)
                && (region == .any || (region == .general) == (article.jurisdiction == "General"))
                && article.matches(query)
        }
    }
}

// MARK: Step carousel

/// Pages are the overview, one per step, then a finish page.
struct GuideCarousel: Equatable, Sendable {
    enum Page: Hashable, Sendable { case overview, step(Int), finish }
    let stepCount: Int
    var index = 0

    var pageCount: Int { stepCount + 2 }
    var page: Page { Self.page(at: index, stepCount: stepCount) }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < pageCount - 1 }
    var stepIndex: Int? { if case .step(let i) = page { i } else { nil } }

    static func page(at index: Int, stepCount: Int) -> Page {
        index <= 0 ? .overview : index > stepCount ? .finish : .step(index - 1)
    }
    mutating func go(to newIndex: Int) { index = min(max(newIndex, 0), pageCount - 1) }
    mutating func forward() { go(to: index + 1) }
    mutating func back() { go(to: index - 1) }

    /// Reopening a guide returns to its first open step, or the overview if nothing has started or it is finished.
    static func resumeIndex(for article: AdultArticle, progress: ArticleProgress) -> Int {
        guard progress.isInProgress(article), let open = article.steps.firstIndex(where: { progress.mark($0) == nil }) else { return 0 }
        return open + 1
    }
}

// MARK: Ask an AI and web search

enum AIDestination: String, CaseIterable, Identifiable, Sendable {
    case none, chatgpt, claude, gemini, copilot, perplexity
    var id: Self { self }
    var title: String {
        switch self {
        case .none: "Just copy"
        case .chatgpt: "ChatGPT"
        case .claude: "Claude"
        case .gemini: "Gemini"
        case .copilot: "Copilot"
        case .perplexity: "Perplexity"
        }
    }
    /// Plain home pages: they open the app when installed, with nothing pre-filled or sent.
    var url: URL? {
        switch self {
        case .none: nil
        case .chatgpt: URL(string: "https://chatgpt.com/")
        case .claude: URL(string: "https://claude.ai/new")
        case .gemini: URL(string: "https://gemini.google.com/app")
        case .copilot: URL(string: "https://copilot.microsoft.com/")
        case .perplexity: URL(string: "https://www.perplexity.ai/")
        }
    }
}

enum AskAIPrompt {
    static let templateKey = "AskAIPromptTemplate"
    static let destinationKey = "AskAIDestination"
    static let includeNotesKey = "AskAIIncludeNotes"
    static let placeholders = ["guide", "summary", "step", "stepDetail", "progress", "region", "supplies", "cautions", "notes"]
    static let defaultTemplate = """
    I'm working through a how-to guide called "{guide}": {summary}
    I'm on this step: {step}
    {stepDetail}

    Where I am: {progress}. Region: {region}.
    What I have: {supplies}
    Cautions from the guide: {cautions}
    {notes}
    Please explain this step simply, tell me what a good result looks like, and list common mistakes. Ask me a question first if something about my situation would change the answer.
    """

    /// Single pass: text inserted for one placeholder is never scanned again, so guide text containing "{step}" stays literal.
    /// Unknown placeholders are kept as typed.
    static func render(_ template: String, values: [String: String]) -> String {
        var output = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            output += rest[..<open]
            let after = rest[rest.index(after: open)...]
            if let close = after.firstIndex(of: "}"), let value = values[String(after[..<close])] {
                output += value
                rest = after[after.index(after: close)...]
            } else {
                output += "{"
                rest = after
            }
        }
        return output + rest
    }

    static func values(article: AdultArticle, stepIndex: Int?, progress: ArticleProgress, includeNotes: Bool) -> [String: String] {
        let step = stepIndex.flatMap { article.steps.indices.contains($0) ? article.steps[$0] : nil }
        let notes = includeNotes ? (progress.personalNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") : ""
        return [
            "guide": article.title,
            "summary": article.summary,
            "step": step.map { "Step \((stepIndex ?? 0) + 1) of \(article.steps.count): \($0.title)" } ?? "the guide as a whole",
            "stepDetail": step?.body ?? article.steps.map { "- " + $0.title }.joined(separator: "\n"),
            "progress": "\(progress.completedCount(in: article)) done, \(progress.knownCount(in: article)) already known, of \(article.steps.count) steps",
            "region": article.jurisdiction,
            "supplies": article.tools.isEmpty ? "nothing special" : article.tools.joined(separator: ", "),
            "cautions": article.cautions.isEmpty ? "none listed" : article.cautions.joined(separator: " "),
            "notes": notes.isEmpty ? "" : "My notes: " + notes + "\n"
        ]
    }

    static func make(template: String?, article: AdultArticle, stepIndex: Int?, progress: ArticleProgress, includeNotes: Bool) -> String {
        let chosen = template?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? template! : defaultTemplate
        return render(chosen, values: values(article: article, stepIndex: stepIndex, progress: progress, includeNotes: includeNotes))
    }
}

enum WebSearch {
    /// RFC 3986 unreserved characters only, so "+", "&", "#" and "=" can't change Google's meaning.
    private static let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func googleURL(_ query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://www.google.com/search?q=" + encoded)
    }

    static func query(article: AdultArticle, stepIndex: Int?) -> String {
        guard let i = stepIndex, article.steps.indices.contains(i) else { return "how to " + article.title.lowercased() }
        return article.steps[i].title + " " + article.title.lowercased()
    }
}

// MARK: Passport stamps (automatic tier)

/// Automatic stamps record finishing a guide; they never claim a skill.
/// Reviewed, self-reported skills stay in AdultPassportStore with their own rules.
struct TopicStamps: Identifiable, Sendable {
    enum Stamp: Sendable { case done, known, open }
    let category: GuideCategory
    let guides: [(article: AdultArticle, stamp: Stamp)]
    var id: String { category.id }
    var earned: Int { guides.filter { $0.stamp != .open }.count }
    var isComplete: Bool { !guides.isEmpty && earned == guides.count }

    static func make(categories: [GuideCategory], articles: [AdultArticle], progress: (String) -> ArticleProgress) -> [TopicStamps] {
        categories.map { category in
            TopicStamps(category: category, guides: articles.filter { $0.categoryID == category.id }.map { article in
                let saved = progress(article.id)
                return (article, !saved.isFinished(article) ? .open : saved.isKnownGuide(article) ? .known : .done)
            })
        }
    }
}

// MARK: Presenter (external display and Mac presenter window)

enum PresenterMode: String, CaseIterable, Identifiable, Sendable {
    case current, expanded, whole
    var id: Self { self }
    var title: String {
        switch self { case .current: "Current step"; case .expanded: "Step and context"; case .whole: "Whole guide" }
    }
    var symbol: String {
        switch self { case .current: "rectangle"; case .expanded: "rectangle.split.2x1"; case .whole: "rectangle.split.3x1" }
    }
}

struct PresenterLayout: Equatable, Sendable {
    let columns: Int
    /// Multiplier on Dynamic Type sizes so text stays readable from across a room.
    let scale: Double

    static func make(size: CGSize, mode: PresenterMode, stepCount: Int) -> PresenterLayout {
        guard size.width > 0, size.height > 0 else { return PresenterLayout(columns: 1, scale: 1) }
        let landscape = size.width >= size.height * 1.15
        let shortSide = min(size.width, size.height)
        let columns: Int
        switch mode {
        case .current: columns = 1
        case .expanded: columns = landscape ? 2 : 1
        case .whole:
            let fit = Int(size.width / (landscape ? 420 : 520))
            columns = min(max(fit, 1), max(stepCount, 1), 4)
        }
        let base = mode == .current ? 2.2 : mode == .expanded ? 1.6 : 1.35
        let scale = min(max(base * shortSide / 1080, 1), 3)
        return PresenterLayout(columns: columns, scale: (scale * 100).rounded() / 100)
    }
}

/// What the device is showing, mirrored by the second screen. One per process.
@MainActor @Observable
final class PresenterState {
    static let shared = PresenterState()
    var articleID: String?
    var pageIndex = 0
    var mode = PresenterMode.expanded
    /// Counted, not a flag: overlapping connect/disconnect callbacks can't leave it wrong.
    var externalDisplayCount = 0
    var externalDisplayConnected: Bool { externalDisplayCount > 0 }
    @ObservationIgnored weak var store: AdultStore?

    enum Command: Sendable { case next, previous, done, known, favorite }
    private(set) var pendingCommand: Command?
    private(set) var commandSerial = 0
    func send(_ command: Command) {
        pendingCommand = command
        commandSerial += 1
    }
}
