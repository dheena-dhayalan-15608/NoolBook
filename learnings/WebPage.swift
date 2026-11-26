//
//  WebPage.swift
//  One page of the NoolStack site inside the app. The site's own header, footer and lesson list are
//  hidden (the app has its own), and the page tells the app what the learner has saved.
//  All pages share one website data store, so signing in, progress, language and theme are shared.
//

import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
final class WebPage: NSObject {
    /// The pages the app keeps: one per area, each reused as the learner moves around.
    static let learn = WebPage(start: "home")
    static let explore = WebPage(start: "syllabus")
    static let debug = WebPage(start: "debug")
    static let account = WebPage(start: "account")

    let webView: WKWebView
    private let start: String
    private(set) var loading = false
    private(set) var failed: String?
    private(set) var route = ""
    private(set) var canGoBack = false
    private var loaded = false
    private var seenEpoch = 0
    private var pageLoads = 0

    private init(start: String) {
        self.start = start
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "NoolStackApp/1.0"
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        config.mediaTypesRequiringUserActionForPlayback = []
        let ucc = config.userContentController
        ucc.addUserScript(WKUserScript(source: Self.bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        ucc.add(WeakHandler(self), name: "noolstack")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(pulled(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        #endif
        #if DEBUG
        if #available(iOS 16.4, macOS 13.3, *) { webView.isInspectable = true }
        #endif
    }

    /// Show a page of the site, such as "lesson-n1". Inside the loaded site this is a quick in-page move.
    func open(_ r: String) {
        failed = nil
        if loaded, failed == nil, webView.url != nil {
            if route != r {
                let js = "location.hash = " + Self.jsString("#/" + r)
                webView.evaluateJavaScript(js)
                route = r
            }
        } else {
            load(r)
        }
    }

    /// Start loading in the background, so the first page shows quickly.
    func warm() { if !loaded && !loading { load(start) } }

    /// Before a page is shown again: if another page changed what this one shows, reload it.
    func refreshIfStale() {
        if loaded && seenEpoch < Learner.shared.epoch {
            seenEpoch = Learner.shared.epoch
            webView.reload()
        }
    }

    func reload() {
        failed = nil
        if webView.url == nil { load(route.isEmpty ? start : route) } else { webView.reload() }
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }

    private func load(_ r: String) {
        route = r
        loading = true
        webView.load(URLRequest(url: Site.url(r)))
    }

    /// Change a saved setting of the site (language or theme), then reload every page.
    static func setSiteValue(_ key: String, _ value: String?) {
        let js = value.map { "localStorage.setItem(\(jsString(key)), \(jsString($0)))" } ?? "localStorage.removeItem(\(jsString(key)))"
        let pages = [learn, explore, debug, account]
        guard let host = pages.first(where: { $0.loaded }) else { return }
        host.webView.evaluateJavaScript(js + "; true") { _, _ in
            Learner.shared.bump()
            for p in pages where p.loaded { p.seenEpoch = Learner.shared.epoch; p.webView.reload() }
        }
    }

    #if os(iOS)
    @objc private func pulled(_ c: UIRefreshControl) {
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { c.endRefreshing() }
    }
    #endif

    fileprivate func received(_ body: Any) {
        guard let m = body as? [String: Any] else { return }
        let before = Learner.shared.epoch
        Learner.shared.update(progress: m["progress"] as? String, lang: m["lang"] as? String, theme: m["theme"] as? String)
        // this page already shows its own change
        if Learner.shared.epoch != before && seenEpoch == before { seenEpoch = Learner.shared.epoch }
        if let h = m["route"] as? String { route = h.hasPrefix("#/") ? String(h.dropFirst(2)) : h }
        canGoBack = webView.canGoBack
    }

    static func jsString(_ s: String) -> String {
        let d = try! JSONSerialization.data(withJSONObject: [s])
        let a = String(data: d, encoding: .utf8)!
        return String(a.dropFirst().dropLast())
    }

    /// Runs in every page before the site starts.
    private static let bridge = #"""
    (function () {
      var post = function () {
        try {
          window.webkit.messageHandlers.noolstack.postMessage({
            progress: localStorage.getItem("ztp-progress-v1"),
            lang: localStorage.getItem("eaas-lang"),
            theme: localStorage.getItem("ztp-theme"),
            route: location.hash
          });
        } catch (e) {}
      };
      try {
        /* The app has its own language setting: the first time, follow the device instead of asking. */
        if (!localStorage.getItem("eaas-lang")) localStorage.setItem("eaas-lang", (navigator.language || "").toLowerCase().indexOf("ta") === 0 ? "ta" : "en");
        var set = Storage.prototype.setItem, rem = Storage.prototype.removeItem;
        var watched = { "ztp-progress-v1": 1, "eaas-lang": 1, "ztp-theme": 1 };
        Storage.prototype.setItem = function (k, v) { set.call(this, k, v); if (this === window.localStorage && watched[k]) setTimeout(post, 0); };
        Storage.prototype.removeItem = function (k) { rem.call(this, k); if (this === window.localStorage && watched[k]) setTimeout(post, 0); };
      } catch (e) {}
      var css = "header.top,footer.sitefoot,#side,.side,.menu,.skip{display:none!important}"
        + "body.course .shell{display:block!important}"
        + "body.course main{margin:0 auto!important;padding-left:clamp(1rem,4vw,2.5rem)!important}"
        + "html{-webkit-text-size-adjust:100%}";
      var addStyle = function () {
        var s = document.createElement("style");
        s.id = "noolstack-app";
        s.textContent = css;
        (document.head || document.documentElement).appendChild(s);
      };
      if (document.head) addStyle(); else document.addEventListener("DOMContentLoaded", addStyle);
      document.documentElement.classList.add("in-app");
      window.addEventListener("hashchange", post);
      window.addEventListener("load", post);
      document.addEventListener("DOMContentLoaded", post);
    })();
    """#
}

/// Keeps the page from being held for ever by its own script handler.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var page: WebPage?
    init(_ p: WebPage) { page = p }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        MainActor.assumeIsolated { page?.received(body) }
    }
}

extension WebPage: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        if url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" { return .allow }
        // links to other sites (and mail, phone and chat links) open outside the app
        if action.targetFrame?.isMainFrame != false && !Site.staysInApp(url) {
            Self.openOutside(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true
        failed = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false
        loaded = true
        pageLoads += 1
        canGoBack = webView.canGoBack
        // a full page load after the first is usually signing in or out: the other pages should catch up
        if pageLoads > 1 && webView.url?.host == Site.base.host {
            Learner.shared.bump()
        }
        seenEpoch = Learner.shared.epoch
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    private func fail(_ error: Error) {
        loading = false
        let e = error as NSError
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        if e.domain == "WebKitErrorDomain" && e.code == 102 { return } // frame load interrupted (a link we opened outside)
        failed = e.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut].contains(e.code)
            ? "You seem to be offline. Connect to the internet, then try again."
            : "This page could not be loaded. Please try again."
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // links that ask for a new window
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if Site.staysInApp(url) { webView.load(action.request) } else { Self.openOutside(url) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
        _ = await Self.ask(message, cancel: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await Self.ask(message, cancel: "Cancel")
    }

    #if os(macOS)
    // choosing files to attach (iOS shows its own picker)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.urls : nil
    }
    #endif

    static func openOutside(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private static func ask(_ message: String, cancel: String?) async -> Bool {
        #if os(iOS)
        guard let top = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { return false }
        var shown = top
        while let p = shown.presentedViewController { shown = p }
        return await withCheckedContinuation { done in
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            if let cancel { a.addAction(UIAlertAction(title: cancel, style: .cancel) { _ in done.resume(returning: false) }) }
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in done.resume(returning: true) })
            shown.present(a, animated: true)
        }
        #else
        let a = NSAlert()
        a.messageText = message
        a.addButton(withTitle: "OK")
        if let cancel { a.addButton(withTitle: cancel) }
        return a.runModal() == .alertFirstButtonReturn
        #endif
    }
}

// MARK: showing a page in SwiftUI

/// Shows a WebPage. The web view moves into whichever screen shows it, so one page can serve many screens.
struct WebPageView: View {
    let page: WebPage

    var body: some View {
        ZStack {
            WebHost(webView: page.webView)
            if let msg = page.failed {
                ContentUnavailableView {
                    Label("Not loaded", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(msg)
                } actions: {
                    Button("Try again") { page.reload() }.buttonStyle(.borderedProminent)
                }
                .background(.background)
            } else if page.loading && page.webView.estimatedProgress < 0.3 {
                ProgressView().controlSize(.large)
            }
        }
    }
}

#if os(iOS)
private struct WebHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> UIView { let v = UIView(); attach(v); return v }
    func updateUIView(_ v: UIView, context: Context) { if webView.superview !== v { attach(v) } }
    private func attach(_ v: UIView) {
        webView.removeFromSuperview()
        webView.frame = v.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.addSubview(webView)
    }
}
#else
private struct WebHost: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> NSView { let v = NSView(); attach(v); return v }
    func updateNSView(_ v: NSView, context: Context) { if webView.superview !== v { attach(v) } }
    private func attach(_ v: NSView) {
        webView.removeFromSuperview()
        webView.frame = v.bounds
        webView.autoresizingMask = [.width, .height]
        v.addSubview(webView)
    }
}
#endif
