import AppKit
import HoulahopUpdater
import SwiftUI

@main
struct SiteioCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updater = Updater()

    var body: some Scene {
        Window("SiteIO", id: "main") {
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

    /// Before any window: drop the old "siteio Companion.app" name, and start again from the new one if this copy moved.
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard case .renamed(let app) = OldAppName.tidy(bundle: Bundle.main.bundleURL,
                                                       bundleID: Bundle.main.bundleIdentifier ?? "") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// One window: closing it quits, like System Settings.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The window: the connect screen, or the server's admin page up to the top of the
/// window, under the transparent title bar (the page leaves room for its buttons),
/// with the footer under it, as AgentIO's.
struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            if let server = model.selected, !model.showsConnect {
                VStack(spacing: 0) {
                    AdminWebView(url: server.launchURL, reloadToken: model.reloadToken)
                        .id(server.id)
                        .ignoresSafeArea(edges: .top)
                    ServerFooter(model: model)
                }
                .frame(minWidth: 900, minHeight: 640)
                .task(id: server.id) { await model.loadVersions() }
            } else {
                ConnectView(model: model)
                    .ignoresSafeArea()
                    .frame(minWidth: 480, minHeight: 560)
            }
        }
        .background(Theme.bg, ignoresSafeAreaEdges: .all)
        .navigationTitle(model.windowTitle)
        // A `siteio login` in the terminal shows up when you come back to the app.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshServers()
        }
    }
}

/// The Server menu: the servers, then the shown one's actions.
struct ServerCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Server") {
            ServerMenuItems(model: model)
            Divider()
            Button("Reload") { model.reload() }
                .keyboardShortcut("r")
                .disabled(model.selected == nil || model.showsConnect)
            Button("Open in Browser") { model.selected.map { _ = NSWorkspace.shared.open($0.adminURL) } }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model.selected == nil)
            Divider()
            if let server = model.selected, server.cliKey != nil, !server.addedInApp {
                // The CLI's servers come from its config: `siteio logout` removes them.
                Button("Remove \(server.name)") {}
                    .disabled(true)
                    .help("Logged in with the siteio CLI: run siteio logout \(server.name)")
            } else if let server = model.selected {
                Button("Remove \(server.name)") { model.remove(server.id) }
            }
        }
    }
}
