import AppKit

/// The page's `alert()`, `confirm()` and `prompt()`, as sheets on the window. WebKit shows none
/// of them unless the app does, and a `confirm()` it does not show answers Cancel: the admin's
/// Remove buttons ask first, so without these they did nothing.
@MainActor struct PagePanels {
    var alert: (String, NSWindow?) async -> Void
    var confirm: (String, NSWindow?) async -> Bool
    var prompt: (String, String?, NSWindow?) async -> String?

    static let sheets = PagePanels(
        alert: { message, window in
            _ = await present(panel(message, buttons: ["OK"]), on: window)
        },
        confirm: { message, window in
            await present(panel(message, buttons: ["OK", "Cancel"]), on: window) == .alertFirstButtonReturn
        },
        prompt: { message, value, window in
            let alert = panel(message, buttons: ["OK", "Cancel"])
            let field = NSTextField(string: value ?? "")
            field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            return await present(alert, on: window) == .alertFirstButtonReturn ? field.stringValue : nil
        }
    )

    /// The message is the page's: shown as text, never as a title the page could style.
    private static func panel(_ message: String, buttons: [String]) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        for title in buttons { alert.addButton(withTitle: title) }
        // Return is OK and Esc is Cancel, as in a browser.
        if buttons.count > 1 { alert.buttons[1].keyEquivalent = "\u{1b}" }
        return alert
    }

    private static func present(_ alert: NSAlert, on window: NSWindow?) async -> NSApplication.ModalResponse {
        guard let window else { return alert.runModal() }
        return await alert.beginSheetModal(for: window)
    }
}
