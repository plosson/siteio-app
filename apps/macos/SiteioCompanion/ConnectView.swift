import SwiftUI

/// The first screen: which siteio server to show. Signing in happens on the server's own page.
struct ConnectView: View {
    let model: AppModel
    @State private var address = ""
    @State private var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .shadow(color: Color.green.opacity(0.25), radius: 14, y: 8)
            Text("Connect to siteio")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.fg)
                .padding(.top, 14)
            Text(verbatim: "Enter your server's domain. You sign in on its admin page. Servers you log in to with the siteio CLI are here already.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text("Server")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                TextField("example.com", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit(connect)
                    .onChange(of: address) { invalid = false }
                // Verbatim: a string literal would be read as Markdown and its URLs turned into links.
                Text(verbatim: invalid ? "Enter a domain, such as example.com or https://api.example.com." : "The admin is at https://api.<domain>/ui.")
                    .font(.system(size: 11.5, weight: invalid ? .semibold : .regular))
                    .foregroundStyle(invalid ? Theme.bad : Theme.muted)
                Button("Connect", action: connect)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 10)
                if model.selected != nil {
                    Button("Cancel") { model.cancelAdding() }
                        .buttonStyle(.link)
                        .keyboardShortcut(.cancelAction)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
            .frame(maxWidth: 380)
            .padding(.top, 24)
            Spacer(minLength: 48)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .onAppear { focused = true }
    }

    private func connect() {
        invalid = !model.connect(to: address)
    }
}

/// The admin page's primary button (`.button.primary`): the system blue in an active or inactive
/// window alike. The bordered prominent style turns white in an inactive window, on a white card.
private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(Theme.link.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}
