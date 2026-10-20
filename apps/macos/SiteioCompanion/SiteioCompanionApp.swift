import AppKit
import HoulahopUpdater
import SwiftUI

@main
struct SiteioCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updater = Updater()

    var body: some Scene {
        Window("siteio Companion", id: "main") {
            RootView(model: appDelegate.model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 760)
        .commands {
            ServerCommands(model: appDelegate.model)
            CommandGroup(after: .appInfo) { CheckForUpdatesButton(updater: updater) }
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel = {
        #if DEBUG
        AppModel(allowLocalHTTP: true)
        #else
        AppModel(allowLocalHTTP: false)
        #endif
    }()

    /// One window: closing it quits, like System Settings.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The window: the connect screen, or the server's admin page up to the top of the
/// window, under the transparent title bar (the page leaves room for its buttons).
struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            if let url = model.adminURL {
                AdminWebView(url: url, reloadToken: model.reloadToken)
                    .id(url)
                    .ignoresSafeArea(edges: .top)
                    .frame(minWidth: 900, minHeight: 640)
            } else {
                ConnectView(model: model)
                    .ignoresSafeArea()
                    .frame(minWidth: 480, minHeight: 560)
            }
        }
        .background(Theme.bg, ignoresSafeAreaEdges: .all)
        .navigationTitle(model.windowTitle)
    }
}

/// The Server menu.
struct ServerCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Server") {
            Button("Reload") { model.reload() }
                .keyboardShortcut("r")
                .disabled(model.adminURL == nil)
            Button("Open in Browser") { model.adminURL.map { _ = NSWorkspace.shared.open($0) } }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model.adminURL == nil)
            Divider()
            Button("Switch Server…") { model.switchServer() }
                .disabled(model.adminURL == nil)
        }
    }
}
