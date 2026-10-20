import SwiftUI

/// The bar under a server's page, as AgentIO's under a vault: which server this is,
/// a way to another one, and which siteio it runs.
struct ServerFooter: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            if let server = model.selected {
                Label(server.name, systemImage: "server.rack").foregroundStyle(Theme.fg)
                Menu("Switch Server…") { ServerMenuItems(model: model) }
                    .fixedSize()
            }
            Spacer(minLength: 16)
            version
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Theme.card)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    @ViewBuilder private var version: some View {
        switch model.footerVersion {
        case .unknown:
            Text("siteio")
        case .version(let version):
            Text("siteio \(version)")
        case .upToDate(let version):
            Text("siteio \(version) · up to date")
        case .updateAvailable(let current, let latest):
            Text("siteio \(current) · \(latest) available")
                .help("Update the server with: siteio update -y && siteio agent restart")
        }
    }
}

/// The servers, one per line with ⌘1…⌘9 and a check on the shown one, then Add Server….
/// Shared by the footer's menu and the Server menu.
struct ServerMenuItems: View {
    let model: AppModel

    var body: some View {
        ForEach(Array(model.servers.enumerated()), id: \.element.id) { index, server in
            let item = Toggle(server.name, isOn: Binding(get: { model.selectedID == server.id && !model.isAdding },
                                                         set: { _ in model.select(server.id) }))
            if index < 9 {
                item.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            } else {
                item
            }
        }
        Divider()
        Button("Add Server…") { model.startAdding() }
            .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}
