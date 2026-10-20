import AppKit
import SwiftUI
import WebKit

/// The server's admin page, up to the top of the window, with the narrow bridge.
/// Pages of other origins (a site, the live editor, docs) open in the browser.
struct AdminWebView: NSViewRepresentable {
    let url: URL
    /// A new value reloads the page (View ▸ Reload).
    let reloadToken: UUID

    func makeCoordinator() -> Coordinator { Coordinator(adminURL: url) }

    func makeNSView(context: Context) -> CompanionWebView {
        let configuration = WKWebViewConfiguration()
        // The default store keeps the admin's session cookie between launches.
        configuration.websiteDataStore = .default()
        let coordinator = context.coordinator
        installBridge(in: configuration.userContentController, handler: BridgeHandler(adminURL: url) { [weak coordinator] call in
            switch call {
            case .dragWindow: coordinator?.webView?.dragWindow()
            }
        })
        let webView = CompanionWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = coordinator
        webView.navigationDelegate = coordinator
        webView.allowsBackForwardNavigationGestures = false
        #if DEBUG
        webView.isInspectable = true
        #endif
        coordinator.webView = webView
        coordinator.reloadToken = reloadToken
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: CompanionWebView, context: Context) {
        guard context.coordinator.reloadToken != reloadToken else { return }
        context.coordinator.reloadToken = reloadToken
        webView.reload()
    }

    static func dismantleNSView(_ webView: CompanionWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    @MainActor final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        let adminOrigin: Origin?
        var reloadToken: UUID?
        weak var webView: CompanionWebView?

        init(adminURL: URL) { adminOrigin = Origin(url: adminURL) }

        /// window.open and target="_blank": http(s) links open in the browser.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            openExternally(action.request.url)
            return nil
        }

        /// The main frame stays on the server's origin; any other page opens in the browser.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard action.targetFrame?.isMainFrame != false, let url = action.request.url,
                  ["http", "https"].contains(url.scheme?.lowercased()) else { return decisionHandler(.allow) }
            if Origin(url: url) == adminOrigin { return decisionHandler(.allow) }
            openExternally(url)
            decisionHandler(.cancel)
        }

        private func openExternally(_ url: URL?) {
            guard let url, ["http", "https", "mailto"].contains(url.scheme?.lowercased()) else { return }
            NSWorkspace.shared.open(url)
        }
    }
}

/// The web view under the transparent title bar, which the page can ask to move the window.
final class CompanionWebView: WKWebView {
    /// The page's `dragWindow()` arrives a moment after its mouse-down, too late for
    /// `performDrag(with:)`, so the window follows the mouse here while the button stays down.
    func dragWindow() {
        guard let window, CGEventSource.buttonState(.hidSystemState, button: .left) else { return }
        let start = NSEvent.mouseLocation
        let origin = window.frame.origin
        // The mouse-up can come before this loop starts; a held button and the 50 ms wait end it then.
        while CGEventSource.buttonState(.hidSystemState, button: .left) {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .leftMouseDown],
                                               until: Date(timeIntervalSinceNow: 0.05),
                                               inMode: .eventTracking, dequeue: true) else { continue }
            guard event.type == .leftMouseDragged else {
                // The page still gets its mouse-up, or the next press.
                NSApp.postEvent(event, atStart: true)
                return
            }
            let now = NSEvent.mouseLocation
            var frame = window.frame
            frame.origin = NSPoint(x: origin.x + now.x - start.x, y: origin.y + now.y - start.y)
            window.setFrameOrigin(window.constrainFrameRect(frame, to: window.screen).origin)
        }
    }

    /// No browser items (reload, back, open link, share): only the ones that edit or read text.
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let prefix = "WKMenuItemIdentifier"
        let kept = Set((["Copy", "Paste", "LookUp", "Translate", "SpellingMenu"] + (isInspectable ? ["InspectElement"] : [])).map { prefix + $0 })
        for item in menu.items where !item.isSeparatorItem {
            let id = item.identifier?.rawValue ?? ""
            let keep = id.hasPrefix(prefix) ? kept.contains(id) : item.action == #selector(NSText.cut(_:))
            if !keep { menu.removeItem(item) }
        }
        var previousIsSeparator = true
        for item in menu.items {
            if item.isSeparatorItem && previousIsSeparator { menu.removeItem(item) } else { previousIsSeparator = item.isSeparatorItem }
        }
        if menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.items.count - 1) }
    }
}
