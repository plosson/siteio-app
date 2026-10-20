import Foundation
import WebKit

/// A call from the admin page's `window.siteioCompanion`. Keep this surface narrow:
/// the page only asks the window to move. No shell, keys or file APIs.
enum BridgeCall: Equatable, Sendable {
    /// Move the window with the mouse: the page calls it on a mouse-down in an
    /// empty part of its sidebar or headers (WKWebView ignores `app-region: drag`).
    case dragWindow

    /// The message `bridgeScript` posts, `{ method, args }`; nil for anything else.
    init?(message body: Any) {
        guard let message = body as? [String: Any], Set(message.keys) == ["method", "args"],
              let method = message["method"] as? String,
              let args = message["args"] as? [Any], args.isEmpty
        else { return nil }
        switch method {
        case "dragWindow": self = .dragWindow
        default: return nil
        }
    }
}

/// The name the bridge's messages arrive under.
let bridgeHandlerName = "siteioCompanion"

/// Defines `window.siteioCompanion` in the admin page, before its own scripts run:
/// the page reads `present` to lay itself out for the window (see ui.js in siteio).
let bridgeScript = """
(() => {
  const call = (method, args) =>
    window.webkit.messageHandlers.\(bridgeHandlerName).postMessage({ method, args });
  Object.defineProperty(window, "siteioCompanion", {
    value: Object.freeze({
      present: true,
      dragWindow: () => call("dragWindow", []),
    }),
  });
})();
"""

/// Scheme, host and port of an origin, with the default port filled in.
struct Origin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int

    init?(url: URL) {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        self.init(scheme: scheme, host: host, port: url.port ?? 0)
    }

    init(scheme: String, host: String, port: Int) {
        self.scheme = scheme.lowercased()
        self.host = host.lowercased()
        self.port = port != 0 ? port : (self.scheme == "https" ? 443 : self.scheme == "http" ? 80 : 0)
    }
}

/// Receives the bridge's messages and drops malformed calls, calls from frames other
/// than the main one, and calls from pages not on the server's own origin (a site's
/// page, opened by mistake, must not move the window or learn it is in the app).
final class BridgeHandler: NSObject, WKScriptMessageHandler {
    private let allowedOrigin: Origin?
    private let onCall: @MainActor (BridgeCall) -> Void

    init(adminURL: URL, onCall: @escaping @MainActor (BridgeCall) -> Void) {
        self.allowedOrigin = Origin(url: adminURL)
        self.onCall = onCall
    }

    /// The call, when the message is one the page may make; nil otherwise.
    nonisolated static func accept(body: Any, isMainFrame: Bool, from origin: Origin, allowed: Origin?) -> BridgeCall? {
        guard isMainFrame, let allowed, origin == allowed else { return nil }
        return BridgeCall(message: body)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        // WebKit delivers script messages on the main thread.
        MainActor.assumeIsolated {
            let security = message.frameInfo.securityOrigin
            let origin = Origin(scheme: security.protocol, host: security.host, port: security.port)
            guard let call = Self.accept(body: message.body, isMainFrame: message.frameInfo.isMainFrame,
                                         from: origin, allowed: allowedOrigin) else { return }
            onCall(call)
        }
    }
}

/// Add the bridge to a web view's configuration, for the main frame's own scripts only.
@MainActor func installBridge(in controller: WKUserContentController, handler: BridgeHandler) {
    controller.addUserScript(WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart,
                                          forMainFrameOnly: true, in: .page))
    controller.add(handler, contentWorld: .page, name: bridgeHandlerName)
}
