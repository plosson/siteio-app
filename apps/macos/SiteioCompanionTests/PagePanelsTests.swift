import WebKit
import XCTest
@testable import SiteIO

/// The page's dialogs reach the app and the app's answer reaches the page. Without the
/// delegate methods, WebKit answers confirm() with false: the admin's Remove did nothing.
@MainActor final class PagePanelsTests: XCTestCase {
    private final class Loaded: NSObject, WKNavigationDelegate {
        let done: XCTestExpectation
        init(_ done: XCTestExpectation) { self.done = done }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done.fulfill() }
    }

    private var asked: [String] = []
    private var offMain = 0

    /// AppKit only builds windows on the main thread: answering anywhere else crashed the app.
    private func note(_ call: String) {
        if !Thread.isMainThread { offMain += 1 }
        asked.append(call)
    }

    override func tearDown() async throws {
        XCTAssertEqual(offMain, 0, "a dialog was answered off the main thread")
    }

    private func page(confirm answer: Bool, prompt reply: String?) async throws -> (CompanionWebView, AdminWebView.Coordinator, Loaded) {
        let panels = PagePanels(
            alert: { [weak self] message, _ in self?.note("alert:" + message) },
            confirm: { [weak self] message, _ in self?.note("confirm:" + message); return answer },
            prompt: { [weak self] message, value, _ in self?.note("prompt:\(message):\(value ?? "nil")"); return reply }
        )
        let coordinator = AdminWebView.Coordinator(adminURL: URL(string: "https://api.example.com/ui")!, panels: panels)
        let webView = CompanionWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), configuration: WKWebViewConfiguration())
        webView.uiDelegate = coordinator
        let loaded = Loaded(expectation(description: "loaded"))
        webView.navigationDelegate = loaded
        webView.loadHTMLString("<p>page</p>", baseURL: URL(string: "https://api.example.com/ui"))
        await fulfillment(of: [loaded.done], timeout: 10)
        return (webView, coordinator, loaded)
    }

    func testConfirmGetsTheAppsAnswer() async throws {
        let (yes, c1, l1) = try await page(confirm: true, prompt: nil)
        let value1 = try await yes.evaluateJavaScript("confirm('Remove site?')") as? Bool
        XCTAssertEqual(value1, true)
        let (no, c2, l2) = try await page(confirm: false, prompt: nil)
        let value2 = try await no.evaluateJavaScript("confirm('Remove app?')") as? Bool
        XCTAssertEqual(value2, false)
        XCTAssertEqual(asked, ["confirm:Remove site?", "confirm:Remove app?"])
        withExtendedLifetime((c1, l1, c2, l2)) {}
    }

    func testAlertAndPromptToo() async throws {
        let (web, c, l) = try await page(confirm: false, prompt: "typed")
        _ = try await web.evaluateJavaScript("alert('Saved'); 1")
        let value3 = try await web.evaluateJavaScript("prompt('Name?', 'x')") as? String
        XCTAssertEqual(value3, "typed")
        XCTAssertEqual(asked, ["alert:Saved", "prompt:Name?:x"])
        withExtendedLifetime((c, l)) {}
    }

    func testACancelledPromptIsNull() async throws {
        let (web, c, l) = try await page(confirm: false, prompt: nil)
        let value4 = try await web.evaluateJavaScript("prompt('Name?') === null") as? Bool
        XCTAssertEqual(value4, true)
        withExtendedLifetime((c, l)) {}
    }

    func testTheMessageIsPassedAsTextNotMarkup() async throws {
        let (web, c, l) = try await page(confirm: false, prompt: nil)
        _ = try await web.evaluateJavaScript(#"confirm("<b>x</b>\nline 2")"#)
        XCTAssertEqual(asked, ["confirm:<b>x</b>\nline 2"])
        withExtendedLifetime((c, l)) {}
    }

    /// The real sheets, on a real window: what crashed when NSAlert was built off the main thread.
    func testTheRealSheetOpensOnTheWindowAndItsButtonsAnswerThePage() async throws {
        let coordinator = AdminWebView.Coordinator(adminURL: URL(string: "https://api.example.com/ui")!)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        let webView = CompanionWebView(frame: window.contentLayoutRect, configuration: WKWebViewConfiguration())
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        webView.uiDelegate = coordinator
        let loaded = Loaded(expectation(description: "loaded"))
        webView.navigationDelegate = loaded
        webView.loadHTMLString("<p>page</p>", baseURL: URL(string: "https://api.example.com/ui"))
        await fulfillment(of: [loaded.done], timeout: 10)

        for (code, expected) in [(NSApplication.ModalResponse.alertFirstButtonReturn, true), (.alertSecondButtonReturn, false)] {
            let answer = Task { @MainActor in try await webView.evaluateJavaScript("confirm('Remove site?')") as? Bool }
            var sheet: NSWindow?
            for _ in 0..<50 where sheet == nil {
                try await Task.sleep(for: .milliseconds(100))
                sheet = window.attachedSheet
            }
            let shown = try XCTUnwrap(sheet, "no sheet on the window")
            XCTAssertTrue(shown.contentView?.subviewsText.contains("Remove site?") == true)
            window.endSheet(shown, returnCode: code)
            let value = try await answer.value
            XCTAssertEqual(value, expected)
        }
        withExtendedLifetime((coordinator, loaded)) {}
    }
}

private extension NSView {
    /// Every label's text under this view.
    var subviewsText: [String] {
        ((self as? NSTextField).map { [$0.stringValue] } ?? []) + subviews.flatMap(\.subviewsText)
    }
}
