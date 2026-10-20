import AppKit
import WebKit
import XCTest
@testable import SiteIO

/// Against a running siteio agent, opt in: `TEST_RUNNER_SITEIO_DEV_URL=http://127.0.0.1:3000/ui?key=<api key>`
/// (xcodebuild passes `TEST_RUNNER_*` to the tests). Skipped otherwise.
@MainActor final class LiveAdminPageTests: XCTestCase {
    private final class Loaded: NSObject, WKNavigationDelegate {
        let done: XCTestExpectation
        init(_ done: XCTestExpectation) { self.done = done }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done.fulfill() }
    }

    func testTheAdminPageSeesTheBridgeAndLaysItselfOutForTheWindow() async throws {
        guard let raw = ProcessInfo.processInfo.environment["SITEIO_DEV_URL"], let url = URL(string: raw) else {
            throw XCTSkip("Set TEST_RUNNER_SITEIO_DEV_URL to run against an agent")
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        var calls: [BridgeCall] = []
        installBridge(in: configuration.userContentController, handler: BridgeHandler(adminURL: url) { calls.append($0) })
        let webView = CompanionWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760), configuration: configuration)
        let loaded = expectation(description: "loaded")
        let delegate = Loaded(loaded)
        webView.navigationDelegate = delegate
        webView.load(URLRequest(url: url))
        await fulfillment(of: [loaded], timeout: 15)
        // Alpine and the page's first fetches.
        try await Task.sleep(for: .seconds(2))

        let present = try await webView.evaluateJavaScript("window.siteioCompanion && window.siteioCompanion.present === true") as? Bool
        XCTAssertEqual(present, true)
        let app = try await webView.evaluateJavaScript("document.documentElement.classList.contains('app')") as? Bool
        XCTAssertEqual(app, true)
        let frozen = try await webView.evaluateJavaScript("(() => { try { window.siteioCompanion.present = false } catch (e) {} ; return window.siteioCompanion.present })()") as? Bool
        XCTAssertEqual(frozen, true)

        // The page's own mousedown handler: empty sidebar chrome asks the app to move the window,
        // a control (a sidebar link) keeps its click.
        let press = "(sel) => document.querySelector(sel).dispatchEvent(new MouseEvent('mousedown', { button: 0, detail: 1, bubbles: true }))"
        _ = try await webView.evaluateJavaScript("(\(press))('.tabs a')")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(calls, [])
        _ = try await webView.evaluateJavaScript("(\(press))('.sidebar')")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(calls, [.dragWindow])
        _ = try await webView.evaluateJavaScript("(\(press))('.pane-head')")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(calls, [.dragWindow, .dragWindow])

        // A picture of the page as the window shows it, in the (sandboxed) temporary directory.
        let image = try await webView.takeSnapshot(configuration: nil)
        let rep = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("siteio-admin-in-app.png")
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: out)
        print("snapshot: \(out.path)")
    }
}
