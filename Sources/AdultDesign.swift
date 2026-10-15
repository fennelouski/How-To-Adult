import SwiftUI

/// Fieldnotes semantic roles. Color assets resolve both appearances without changing teaching art.
enum AdultPalette {
    static let background = Color("Paper")
    static let surface = Color("RaisedPaper")
    static let ink = Color("PineInk")
    static let secondaryText = Color("SecondaryText")
    static let accent = Color("AccentColor")
    static let rule = Color("PaperRule")
    static let caution = Color("CautionPaper")
    static func category(_ key: String) -> Color { accent }
}

struct FieldnotesHeading: View {
    let title: String
    @ScaledMetric private var size: CGFloat
    init(_ title: String, size: CGFloat, relativeTo: Font.TextStyle = .title2) {
        self.title = title
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
    }
    var body: some View {
        Text(title).font(.system(size: size, weight: .regular, design: .serif))
            .tracking(-0.6).foregroundStyle(AdultPalette.ink)
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
}

private struct FieldnotesBody: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    init(size: CGFloat, weight: Font.Weight) { _size = ScaledMetric(wrappedValue: size, relativeTo: .body); self.weight = weight }
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight)).lineSpacing(size * 0.22).fixedSize(horizontal: false, vertical: true)
    }
}
extension View {
    func fieldnotesBody(size: CGFloat = 17, weight: Font.Weight = .regular) -> some View { modifier(FieldnotesBody(size: size, weight: weight)) }
}
struct FieldnotesRule: View {
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View { Rectangle().fill(AdultPalette.rule).frame(height: contrast == .increased ? 2 : 1).accessibilityHidden(true) }
}
struct FieldnotesWordmark: View {
    var body: some View {
        HStack(spacing: 8) { Image(systemName: "book"); Text("How to Adult").font(.system(.headline, design: .serif, weight: .semibold)) }
            .foregroundStyle(AdultPalette.ink).accessibilityElement(children: .combine)
    }
}
