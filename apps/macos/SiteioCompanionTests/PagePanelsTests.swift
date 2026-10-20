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

    private func page(confirm answer: Bool, prompt reply: String?) async throws -> (CompanionWebView, AdminWebView.Coordinator, Loaded) {
        let panels = PagePanels(
            alert: { [weak self] message, _ in self?.asked.append("alert:" + message) },
            confirm: { [weak self] message, _ in self?.asked.append("confirm:" + message); return answer },
            prompt: { [weak self] message, value, _ in self?.asked.append("prompt:\(message):\(value ?? "nil")"); return reply }
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
}
