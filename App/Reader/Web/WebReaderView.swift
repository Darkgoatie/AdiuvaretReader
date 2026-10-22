import SwiftUI
import WebKit
import ReaderDesign

#if canImport(UIKit)
import UIKit
typealias PlatformRepresentable = UIViewRepresentable
#else
import AppKit
typealias PlatformRepresentable = NSViewRepresentable
#endif

@MainActor
final class WebReaderController {
    weak var webView: WKWebView?

    func text() async -> String {
        guard let webView else { return "" }
        let result = try? await webView.evaluateJavaScript("window.rd ? window.rd.text() : ''", in: nil, contentWorld: .defaultClient)
        return (result as? String) ?? ""
    }

    func clearSelection() {
        webView?.evaluateJavaScript("window.rd && window.rd.clearSelection()", in: nil, in: .defaultClient, completionHandler: nil)
    }
}

/// What the page should show: a file, how far down, what to find and which anchor to scroll to.
struct WebRequest: Equatable {
    let id = UUID()
    var url: URL
    var fraction: Double = 0
    var find: String?
    var anchor: String?
}

struct WebReaderView: PlatformRepresentable {
    let request: WebRequest
    let readAccess: URL
    let css: String
    let ground: String
    let dark: Bool
    let highlights: [WebHighlight]
    let ink: WebInk?
    /// The chapter the ink belongs to, such as c3.
    let inkPage: String
    let controller: WebReaderController
    let onSelection: (String) -> Void
    let onScroll: (Double) -> Void
    let onTap: (Double) -> Void
    /// Called for a tapped link to another file. Return true when the app handled it.
    let onLink: (URL) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebReaderView
        var css = ""
        var loadedURL: URL?
        var lastRequestID: UUID?
        var ready = false
        var highlights: [WebHighlight] = []
        var current: WebRequest?
        static var blockList: WKContentRuleList?

        init(_ parent: WebReaderView) { self.parent = parent }

        func install(on view: WKWebView, css: String) {
            let controller = view.configuration.userContentController
            controller.removeAllUserScripts()
            let hide = "(function(){document.documentElement.style.background='\(parent.ground)';})();" + WebBridge.hideUntilReady
            controller.addUserScript(WKUserScript(source: hide, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .defaultClient))
            if !WebAssets.katexScript.isEmpty {
                controller.addUserScript(WKUserScript(source: WebAssets.katexScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
            }
            if parent.ink != nil {
                let lock = "(function(){var m=document.querySelector('meta[name=viewport]');if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}m.content='width=device-width,initial-scale=1,minimum-scale=1,maximum-scale=1,user-scalable=no';})();"
                controller.addUserScript(WKUserScript(source: lock, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
            }
            controller.addUserScript(WKUserScript(source: WebBridge.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
            self.css = css
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["t"] as? String else { return }
            switch type {
            case "sel": parent.onSelection((body["v"] as? String) ?? "")
            case "scroll": if let v = body["v"] as? Double { parent.onScroll(v) }
            case "tap": if let v = body["v"] as? Double { parent.onTap(v) }
            default: break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if navigationAction.navigationType == .linkActivated, let scheme = url.scheme, scheme.hasPrefix("obsidian-") {
                _ = parent.onLink(url)
                return .cancel
            }
            if navigationAction.navigationType != .linkActivated { return url.isFileURL || url.scheme == "about" ? .allow : .cancel }
            if url.isFileURL {
                let same = url.deletingFragment().standardizedFileURL == loadedURL?.standardizedFileURL
                if same { return .allow }
                _ = parent.onLink(url)
                return .cancel
            }
            if url.scheme == "http" || url.scheme == "https" {
                #if canImport(UIKit)
                _ = await UIApplication.shared.open(url)
                #else
                NSWorkspace.shared.open(url)
                #endif
            }
            return .cancel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            Task { await finishLoad(webView) }
        }

        func finishLoad(_ webView: WKWebView) async {
            func run(_ js: String) async { _ = try? await webView.evaluateJavaScript(js, in: nil, contentWorld: .defaultClient) }
            await run("window.rd.setCSS(\(WebBridge.jsString(css)))")
            if let style = WebAssets.katexStyleURL {
                await run("window.rd.link(\(WebBridge.jsString(style.absoluteString)))")
            }
            if loadedURL?.path.contains("/pages/") == true {
                await run("window.rd.math()")
                await drawMolecules(in: webView)
            }
            highlights = parent.highlights
            await run("window.rd.setHighlights(\(WebBridge.jsHighlights(highlights)))")
            await perform(current, in: webView)
            await run("window.rd.show()")
            parent.ink?.lockZoom()
            parent.ink?.show(page: parent.inkPage)
        }

        /// Draws molecule blocks with RDKit. The engine is sent to the page only when the page has such a block.
        func drawMolecules(in webView: WKWebView) async {
            let has = try? await webView.evaluateJavaScript("!!document.querySelector('.chem-block, .chem-cell')", in: nil, contentWorld: .defaultClient) as? Bool
            guard has == true, !WebAssets.chemScript.isEmpty else { return }
            _ = try? await webView.evaluateJavaScript("window.__rdDark = \(parent.dark)", in: nil, contentWorld: .defaultClient)
            _ = try? await webView.evaluateJavaScript(WebAssets.chemScript, in: nil, contentWorld: .defaultClient)
            for chunk in WebAssets.chemWasmChunks() {
                _ = try? await webView.evaluateJavaScript("window.rdChemPush('\(chunk)')", in: nil, contentWorld: .defaultClient)
            }
            let first = try? await webView.callAsyncJavaScript("return await window.rdChem();", arguments: [:], in: nil, contentWorld: .defaultClient) as? Int
            // One more try after a failed start, so a single bad moment does not leave the page without drawings.
            if first == -1 {
                try? await Task.sleep(for: .seconds(2.2))
                _ = try? await webView.callAsyncJavaScript("return await window.rdChem();", arguments: [:], in: nil, contentWorld: .defaultClient)
            }
        }

        func perform(_ request: WebRequest?, in webView: WKWebView) async {
            guard let request else { return }
            func run(_ js: String) async { _ = try? await webView.evaluateJavaScript(js, in: nil, contentWorld: .defaultClient) }
            if let anchor = request.anchor {
                await run("window.rd.scrollToAnchor(\(WebBridge.jsString(anchor)))")
            } else if request.fraction > 0 {
                await run("window.rd.scrollToFraction(\(request.fraction))")
            } else {
                await run("window.scrollTo(0,0)")
            }
            if let q = request.find, !q.isEmpty {
                await run("window.rd.find(\(WebBridge.jsString(q)))")
            } else {
                await run("window.rd.clearFind()")
            }
        }
    }

    // MARK: Shared setup

    private func build(_ context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.userContentController.add(context.coordinator, contentWorld: .defaultClient, name: "rd")
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        context.coordinator.install(on: view, css: css)
        controller.webView = view
        #if canImport(UIKit)
        ink?.attach(to: view)
        ink?.dark = dark
        #endif
        Task { @MainActor in
            if Coordinator.blockList == nil {
                Coordinator.blockList = try? await WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "reader-no-network",
                    encodedContentRuleList: #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#)
            }
            if let list = Coordinator.blockList { view.configuration.userContentController.add(list) }
        }
        #if canImport(UIKit)
        let bg = UIColor(Color(hex: ground))
        view.isOpaque = false
        view.backgroundColor = bg
        view.scrollView.backgroundColor = bg
        #endif
        apply(to: view, coordinator: context.coordinator)
        return view
    }

    private func apply(to view: WKWebView, coordinator c: Coordinator) {
        c.parent = self
        ink?.dark = dark
        if css != c.css {
            c.install(on: view, css: css)
            if c.ready {
                view.evaluateJavaScript("window.rd.setCSS(\(WebBridge.jsString(css)));window.__rdDark=\(dark);window.rdChemTheme&&window.rdChemTheme()", in: nil, in: .defaultClient, completionHandler: nil)
                ink?.refreshLayout()
            }
        }
        if request.id != c.lastRequestID {
            c.lastRequestID = request.id
            c.current = request
            if request.url.deletingFragment().standardizedFileURL == c.loadedURL?.standardizedFileURL, c.ready {
                Task { await c.perform(request, in: view) }
            } else {
                ink?.leavePage()
                c.loadedURL = request.url.deletingFragment()
                c.ready = false
                view.loadFileURL(request.url.deletingFragment(), allowingReadAccessTo: readAccess)
            }
        }
        if c.ready, highlights != c.highlights {
            c.highlights = highlights
            view.evaluateJavaScript("window.rd.setHighlights(\(WebBridge.jsHighlights(highlights)))", in: nil, in: .defaultClient, completionHandler: nil)
        }
    }

    #if canImport(UIKit)
    func makeUIView(context: Context) -> WKWebView { build(context) }
    func updateUIView(_ view: WKWebView, context: Context) { apply(to: view, coordinator: context.coordinator) }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "rd", contentWorld: .defaultClient)
    }
    #else
    func makeNSView(context: Context) -> WKWebView { build(context) }
    func updateNSView(_ view: WKWebView, context: Context) { apply(to: view, coordinator: context.coordinator) }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "rd", contentWorld: .defaultClient)
    }
    #endif
}

extension URL {
    func deletingFragment() -> URL {
        var c = URLComponents(url: self, resolvingAgainstBaseURL: false)
        c?.fragment = nil
        return c?.url ?? self
    }
}

extension Color {
    init(hex: String) {
        let c = WallpaperColor.rgb(hex) ?? (0.5, 0.5, 0.5)
        self.init(red: c.r, green: c.g, blue: c.b)
    }
}
