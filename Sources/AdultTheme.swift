import SwiftUI

// MARK: Category visual language

/// Each topic has a color, an icon and a shape. Unknown future topics fall back to the catalog's colorKey and a rounded square.
struct CategoryStyle {
    enum Motif { case squares, circles, triangles, bars, waves, rings, dots }
    let ground: Color      // Tile background behind white text. Deep enough for 4.5:1 in both appearances.
    let tint: Color        // Icons and progress on ordinary backgrounds; lighter in dark mode.
    let motif: Motif
    let shape: AnyShape

    static func of(_ categoryID: String?, colorKey: String = "blue") -> CategoryStyle {
        switch categoryID {
        case "home": make(0x0F6E74, 0x5FD4D9, .squares, AnyShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
        case "food": make(0xA9481A, 0xFFA36B, .circles, AnyShape(Circle()))
        case "money": make(0x2C6E37, 0x7FD68B, .triangles, AnyShape(Diamond()))
        case "work": make(0x1F4E99, 0x86AEF5, .bars, AnyShape(RoundedRectangle(cornerRadius: 4, style: .continuous)))
        case "wellbeing": make(0xA8325A, 0xFF8FB4, .waves, AnyShape(Capsule()))
        case "people": make(0x6B3FA0, 0xC6A2F2, .rings, AnyShape(Ellipse()))
        case "everyday": make(0x3D47A3, 0x9AA3F5, .dots, AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
        default:
            CategoryStyle(ground: AdultPalette.category(colorKey), tint: AdultPalette.category(colorKey), motif: .dots,
                          shape: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
        }
    }

    private static func make(_ ground: UInt32, _ darkTint: UInt32, _ motif: Motif, _ shape: AnyShape) -> CategoryStyle {
        CategoryStyle(ground: Color(hex: ground), tint: .adaptive(light: Color(hex: ground), dark: Color(hex: darkTint)), motif: motif, shape: shape)
    }
}

extension AdultStore {
    func style(_ article: AdultArticle) -> CategoryStyle {
        CategoryStyle.of(article.categoryID, colorKey: category(article)?.colorKey ?? "blue")
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .vibrantDark]) != nil ? NSColor(dark) : NSColor(light) })
        #else
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #endif
    }
}

/// Decorative background pattern in the category's shape language.
struct MotifPattern: View {
    let motif: CategoryStyle.Motif
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 26
            var row = 0
            for y in stride(from: CGFloat(0), through: size.height + step, by: step) {
                let offset: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
                for x in stride(from: -offset, through: size.width + step, by: step) {
                    let r = CGRect(x: x, y: y, width: 12, height: 12)
                    let path: Path
                    switch motif {
                    case .squares: path = Path(roundedRect: r, cornerRadius: 3)
                    case .circles: path = Path(ellipseIn: r)
                    case .triangles: path = Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
                    case .bars: path = Path(roundedRect: CGRect(x: x, y: y + 4, width: 18, height: 4), cornerRadius: 2)
                    case .waves: path = Path { p in p.move(to: CGPoint(x: x, y: y + 6)); p.addQuadCurve(to: CGPoint(x: x + 13, y: y + 6), control: CGPoint(x: x + 6.5, y: y - 2)); p.addQuadCurve(to: CGPoint(x: x + 26, y: y + 6), control: CGPoint(x: x + 19.5, y: y + 14)) }
                    case .rings: path = Path(ellipseIn: r).strokedPath(StrokeStyle(lineWidth: 2))
                    case .dots: path = Path(ellipseIn: CGRect(x: x + 3, y: y + 3, width: 5, height: 5))
                    }
                    if motif == .waves { context.stroke(path, with: .color(.white), lineWidth: 2) } else { context.fill(path, with: .color(.white)) }
                }
                row += 1
            }
        }
        .opacity(0.13)
        .accessibilityHidden(true)
    }
}

/// An SF Symbol inside the category's shape.
struct CategoryBadge: View {
    let style: CategoryStyle
    let symbol: String
    var size: CGFloat = 48
    var dimmed = false
    var body: some View {
        style.shape.fill(dimmed ? AnyShapeStyle(style.tint.opacity(0.25)) : AnyShapeStyle(style.ground))
            .frame(width: size, height: size)
            .overlay { Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white) }
            .accessibilityHidden(true)
    }
}

// MARK: Progress

/// One segment per step: filled when done, half-tone with a check when known, empty when open.
struct StepSegments: View {
    let article: AdultArticle
    let progress: ArticleProgress
    let tint: Color
    var current: Int? = nil
    var height: CGFloat = 6

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(article.steps.enumerated()), id: \.offset) { index, step in
                let mark = progress.mark(step)
                Capsule()
                    .fill(mark == .done ? AnyShapeStyle(tint) : mark == .known ? AnyShapeStyle(tint.opacity(0.4)) : AnyShapeStyle(Color.secondary.opacity(0.2)))
                    .overlay { if index == current { Capsule().strokeBorder(Color.primary, lineWidth: 1.5) } }
                    .frame(height: height)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(Self.description(article: article, progress: progress))
    }

    static func description(article: AdultArticle, progress: ArticleProgress) -> String {
        let done = progress.completedCount(in: article), known = progress.knownCount(in: article)
        return "\(done) of \(article.steps.count) done" + (known > 0 ? ", \(known) already known" : "")
    }
}

struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 5
    var color: Color = .white
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: lineWidth)
            Circle().trim(from: 0, to: fraction).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(-90))
        }
    }
}

// MARK: Chips

/// A compact, icon-led toggle used for filters.
struct FilterChip: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(isOn ? AnyShapeStyle(AdultPalette.accent) : AnyShapeStyle(AdultPalette.surface), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A small icon + value fact, e.g. ⏱ 10 min.
struct Fact: View {
    let symbol: String
    let text: String
    var label: String? = nil
    var body: some View {
        Label(text, systemImage: symbol).labelStyle(.titleAndIcon).font(.caption.weight(.semibold))
            .foregroundStyle(AdultPalette.secondaryText)
            .accessibilityLabel(label ?? text)
    }
}

// MARK: Guide card

struct GuideCard: View {
    @Environment(AdultStore.self) private var store
    let article: AdultArticle

    var body: some View {
        let style = store.style(article)
        let progress = store.progress(article.id)
        let known = progress.isKnownGuide(article)
        HStack(alignment: .top, spacing: 14) {
            CategoryBadge(style: style, symbol: article.symbol, size: 50, dimmed: known)
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Fact(symbol: "clock", text: "\(article.minutes) min", label: "About \(article.minutes) minutes")
                    if article.jurisdiction != "General" { Fact(symbol: "globe.americas", text: "US", label: article.jurisdiction + " rules") }
                    if progress.isSaved { Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink).accessibilityLabel("Favorite") }
                }
                StepSegments(article: article, progress: progress, tint: style.tint)
            }
            Spacer(minLength: 0)
            if progress.isFinished(article) {
                Image(systemName: known ? "checkmark.seal" : "checkmark.seal.fill").font(.title2).foregroundStyle(style.tint)
                    .accessibilityLabel(known ? "Already known" : "Finished")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(known ? 0.6 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("guide-" + article.id)
    }
}

/// Grid columns that collapse to one at accessibility sizes.
struct AdaptiveColumns {
    static func guides(_ typeSize: DynamicTypeSize) -> [GridItem] {
        [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 600 : 300), spacing: 12, alignment: .top)]
    }
}

/// A spring that becomes an instant change under Reduce Motion.
extension Animation {
    static func adult(_ reduceMotion: Bool) -> Animation? { reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82) }
}
