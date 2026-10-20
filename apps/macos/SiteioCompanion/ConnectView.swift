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
            Text("Enter your server's domain. You sign in on its admin page.")
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
                Text(invalid ? "Enter a domain, such as example.com or https://api.example.com." : "The admin is at https://api.<domain>/ui.")
                    .font(.system(size: 11.5, weight: invalid ? .semibold : .regular))
                    .foregroundStyle(invalid ? Theme.bad : Theme.muted)
                Button(action: connect) {
                    Text("Connect").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, 10)
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
