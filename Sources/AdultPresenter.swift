import SwiftUI

/// A purpose-built second screen: never a mirror of the device UI.
/// It reads PresenterState, which the guide carousel updates as you move.
struct PresenterRoot: View {
    private let state = PresenterState.shared

    var body: some View {
        Group {
            if let store = state.store {
                PresenterContent(state: state).environment(store)
            } else {
                Color.black
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PresenterContent: View {
    @Environment(AdultStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: PresenterState

    var body: some View {
        GeometryReader { geometry in
            let article = state.articleID.flatMap(store.article)
            let layout = PresenterLayout.make(size: geometry.size, mode: state.mode, stepCount: article?.steps.count ?? 1)
            ZStack {
                Color.black.ignoresSafeArea()
                if let article {
                    let style = store.style(article)
                    style.ground.opacity(0.25).ignoresSafeArea()
                    MotifPattern(motif: style.motif).opacity(0.25).ignoresSafeArea()
                    // Never truncate (cautions are safety text): try smaller scales until the mode fits.
                    ViewThatFits(in: .vertical) {
                        ForEach([1.0, 0.82, 0.68, 0.56, 0.46], id: \.self) { factor in
                            content(article, style: style, layout: PresenterLayout(columns: layout.columns, scale: layout.scale * factor),
                                    height: geometry.size.height * 0.92)
                        }
                    }
                        .padding(geometry.size.width * 0.04)
                        .id(state.mode)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 20 * layout.scale) {
                        Image(systemName: "book.pages").font(.system(size: 90 * layout.scale)).foregroundStyle(.white.opacity(0.8))
                        Text("How to Adult").font(.system(size: 40 * layout.scale, weight: .bold, design: .serif)).fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
                    }
                }
            }
            .animation(.adult(reduceMotion), value: state.pageIndex)
            .animation(.adult(reduceMotion), value: state.mode)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("presenter-root")
    }

    @ViewBuilder private func content(_ article: AdultArticle, style: CategoryStyle, layout: PresenterLayout, height: Double) -> some View {
        let page = GuideCarousel.page(at: state.pageIndex, stepCount: article.steps.count)
        let progress = store.progress(article.id)
        let s = layout.scale
        switch state.mode {
        case .current:
            VStack(alignment: .leading, spacing: 24 * s) {
                header(article, page: page, style: style, scale: s)
                pageBody(article, page: page, scale: s)
                Spacer(minLength: 0)
                StepSegments(article: article, progress: progress, tint: style.tint, current: page.stepIndex, height: 10 * s)
            }
        case .expanded:
            VStack(alignment: .leading, spacing: 20 * s) {
                header(article, page: page, style: style, scale: s)
                if layout.columns > 1 {
                    HStack(alignment: .top, spacing: 32 * s) {
                        pageBody(article, page: page, scale: s).frame(maxWidth: .infinity, alignment: .leading)
                        context(article, page: page, scale: s).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    pageBody(article, page: page, scale: s)
                    context(article, page: page, scale: s)
                }
                Spacer(minLength: 0)
                StepSegments(article: article, progress: progress, tint: style.tint, current: page.stepIndex, height: 8 * s)
            }
        case .whole:
            // A non-interactive screen can't be scrolled by hand, so it follows the current step itself.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16 * s) {
                        Text(article.title).font(.system(size: 34 * s, weight: .bold, design: .serif)).fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18 * s, alignment: .top), count: layout.columns), spacing: 18 * s) {
                            ForEach(Array(article.steps.enumerated()), id: \.offset) { i, step in
                                stepCard(step, index: i, current: page.stepIndex == i, mark: progress.mark(step), tint: style.tint, scale: s).id(i)
                            }
                        }
                        HStack(alignment: .top, spacing: 24 * s) {
                            if !article.tools.isEmpty { infoBlock("shippingbox", article.tools.joined(separator: " · "), scale: s * 0.9, tint: style.tint) }
                            if !article.cautions.isEmpty { infoBlock("exclamationmark.triangle.fill", article.cautions.joined(separator: " "), scale: s * 0.9, tint: .orange) }
                        }
                    }
                    .frame(minHeight: height) // centered when it fits; scrolls to the current step when it doesn't
                }
                .scrollDisabled(true)
                .scrollIndicators(.hidden)
                .onAppear { if let i = page.stepIndex { proxy.scrollTo(i, anchor: .center) } }
                .onChange(of: state.pageIndex) { _, _ in
                    if let i = page.stepIndex { withAnimation(.adult(reduceMotion)) { proxy.scrollTo(i, anchor: .center) } }
                }
            }
        }
    }

    private func stepCard(_ step: GuideStep, index i: Int, current: Bool, mark: StepMark?, tint: Color, scale s: Double) -> some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            HStack(spacing: 8 * s) {
                Text("\(i + 1)").font(.system(size: 22 * s, weight: .heavy, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                if let mark { Image(systemName: mark == .done ? "checkmark.circle.fill" : "lightbulb.fill").font(.system(size: 20 * s)) }
            }.foregroundStyle(tint)
            Text(step.title).font(.system(size: 22 * s, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Text(step.body).font(.system(size: 17 * s)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(16 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(current ? 0.18 : 0.07), in: RoundedRectangle(cornerRadius: 18 * s, style: .continuous))
        .overlay { if current { RoundedRectangle(cornerRadius: 18 * s, style: .continuous).strokeBorder(tint, lineWidth: 3) } }
        .opacity(mark == nil || current ? 1 : 0.6)
    }

    private func header(_ article: AdultArticle, page: GuideCarousel.Page, style: CategoryStyle, scale s: Double) -> some View {
        HStack(spacing: 16 * s) {
            CategoryBadge(style: style, symbol: article.symbol, size: 56 * s)
            if page != .overview {
                Text(article.title).font(.system(size: 26 * s, weight: .semibold, design: .serif)).fixedSize(horizontal: false, vertical: true).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            if case .step(let i) = page {
                Text("\(i + 1)/\(article.steps.count)").font(.system(size: 26 * s, weight: .bold, design: .rounded)).fixedSize(horizontal: false, vertical: true).foregroundStyle(style.tint)
            }
        }
    }

    @ViewBuilder private func pageBody(_ article: AdultArticle, page: GuideCarousel.Page, scale s: Double) -> some View {
        switch page {
        case .overview:
            VStack(alignment: .leading, spacing: 14 * s) {
                Text(article.title).font(.system(size: 48 * s, weight: .bold, design: .serif)).fixedSize(horizontal: false, vertical: true)
                Text(article.summary).font(.system(size: 26 * s)).fixedSize(horizontal: false, vertical: true).opacity(0.85)
                HStack(spacing: 24 * s) {
                    Label("\(article.minutes) min", systemImage: "clock")
                    Label("\(article.steps.count)", systemImage: "list.number")
                    if article.jurisdiction != "General" { Label(article.jurisdiction, systemImage: "globe.americas.fill") }
                }.font(.system(size: 22 * s, weight: .semibold))
            }.foregroundStyle(.white)
        case .step(let i):
            VStack(alignment: .leading, spacing: 16 * s) {
                Text(article.steps[i].title).font(.system(size: 52 * s, weight: .regular, design: .serif)).fixedSize(horizontal: false, vertical: true)
                Text(article.steps[i].body).font(.system(size: 30 * s)).fixedSize(horizontal: false, vertical: true)
            }.foregroundStyle(.white)
        case .finish:
            Label("Finished", systemImage: "checkmark.seal.fill").font(.system(size: 56 * s, weight: .bold)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private func context(_ article: AdultArticle, page: GuideCarousel.Page, scale s: Double) -> some View {
        VStack(alignment: .leading, spacing: 16 * s) {
            if !article.tools.isEmpty { infoBlock("shippingbox", article.tools.joined(separator: "\n"), scale: s, tint: store.style(article).tint) }
            if !article.cautions.isEmpty { infoBlock("exclamationmark.triangle.fill", article.cautions.joined(separator: "\n"), scale: s, tint: .orange) }
            if let i = page.stepIndex, i + 1 < article.steps.count {
                infoBlock("arrow.turn.down.right", article.steps[i + 1].title, scale: s, tint: .white)
            } else if page == .overview, let first = article.steps.first {
                infoBlock("arrow.turn.down.right", first.title, scale: s, tint: .white)
            }
        }
    }

    private func infoBlock(_ symbol: String, _ text: String, scale s: Double, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12 * s) {
            Image(systemName: symbol).font(.system(size: 24 * s, weight: .semibold)).foregroundStyle(tint).frame(width: 32 * s)
            Text(text).font(.system(size: 22 * s)).fixedSize(horizontal: false, vertical: true).foregroundStyle(.white.opacity(0.9))
        }
        .padding(14 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16 * s, style: .continuous))
    }
}

private extension GuideCarousel.Page {
    var stepIndex: Int? { if case .step(let i) = self { i } else { nil } }
}

/// Mode switcher shown inside the Mac presenter window.
struct PresenterWindow: View {
    private let state = PresenterState.shared
    var body: some View {
        PresenterRoot()
            .toolbar {
                ToolbarItem {
                    Picker("Layout", selection: Binding(get: { state.mode }, set: { state.mode = $0 })) {
                        ForEach(PresenterMode.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }.pickerStyle(.segmented)
                }
            }
            .frame(minWidth: 480, minHeight: 300)
    }
}

#if os(iOS)
import UIKit
import os

private let presenterLog = Logger(subsystem: "com.nathanfennel.How-To-Adult", category: "presenter")

/// Gives external displays their own scene instead of mirroring.
final class AdultAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        presenterLog.info("Configuring scene for role \(session.role.rawValue, privacy: .public)")
        if session.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
        }
        return configuration
    }
}

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        presenterLog.info("External display connected: \(windowScene.screen.bounds.width, privacy: .public)x\(windowScene.screen.bounds.height, privacy: .public), store \(PresenterState.shared.store == nil ? "missing" : "ready", privacy: .public)")
        let window = UIWindow(windowScene: windowScene)
        let host = UIHostingController(rootView: PresenterRoot())
        host.view.backgroundColor = .black
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        PresenterState.shared.externalDisplayCount += 1
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        presenterLog.info("External display disconnected")
        if window != nil { PresenterState.shared.externalDisplayCount = max(0, PresenterState.shared.externalDisplayCount - 1) }
        window?.isHidden = true
        window = nil
    }
}
#endif
