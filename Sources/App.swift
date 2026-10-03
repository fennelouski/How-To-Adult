import SwiftUI

@main
struct HowToAdultApp: App {
    @State private var store = AdultStore()

    var body: some Scene {
        WindowGroup {
            AdultRootView()
                .environment(store)
                #if DEBUG
                .modifier(AdultQAAppearance())
                #endif
                #if os(macOS)
                .frame(minWidth: 680, minHeight: 520)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 820)
        #endif
    }
}

#if DEBUG
private struct AdultQAAppearance: ViewModifier {
    @Environment(\.dynamicTypeSize) private var inheritedTypeSize

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--qa-dark") ? .dark : nil)
            .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--qa-accessibility-text") ? .accessibility3 : inheritedTypeSize)
    }
}
#endif
