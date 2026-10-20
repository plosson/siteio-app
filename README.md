# SiteIO

Native macOS app (Swift, SwiftUI) for a [siteio](https://github.com/plosson/siteio) server: one window that shows the server's admin page (`https://api.<domain>/ui`), as the AgentIO app does for an agentio hub.

## Install

Open `SiteIO-<version>.pkg` from the [latest release](https://github.com/plosson/siteio-app/releases/latest), or `brew install --cask plosson/tap/siteio-companion`. The app updates itself (Sparkle); **SiteIO ▸ Check for Updates…** checks now.

The admin page is the server's own: new siteio features need no app update. You sign in on that page (username and password, or the API key); the session cookie is kept between launches.

## Build, test and run

```bash
cd apps/macos
xcodegen generate                       # creates SiteioCompanion.xcodeproj (not committed)
xcodebuild -scheme SiteioCompanion -destination 'platform=macOS' -derivedDataPath build test
xcodebuild -scheme SiteioCompanion -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SiteIO.app
```

Requirements: macOS 14 or later, Xcode 26, XcodeGen (`brew install xcodegen`), and a siteio agent 1.50.0 or later (the version whose admin page knows the bridge).

Against a local agent, Debug builds accept `http://localhost:<port>` or `http://127.0.0.1:<port>`; Release builds accept https only. One test drives a real admin page and is skipped unless you name one:

```bash
TEST_RUNNER_SITEIO_DEV_URL="http://127.0.0.1:3000/ui?key=<api key>" xcodebuild -scheme SiteioCompanion -destination 'platform=macOS' -derivedDataPath build test
```

## Release

```bash
git submodule update --init                     # scripts/mac-release (houlahop-mac-release), shared with the AgentIO app
DEVELOPMENT_TEAM=427N276E3Q scripts/release.sh 0.1.0
```

Tests, then a Developer ID build, notarized and stapled, as a pkg and a zip, with a signed Sparkle appcast, published as a GitHub release; then the Homebrew cask. Needs the Developer ID Application and Installer certificates, `asc` signed in, `gh`, and the Sparkle key in the login keychain (account `siteio-companion`; its public key is `SUPublicEDKey` in `project.yml`). Back that key up: without it, no update can reach installed copies.

## Where the app keeps things

| What | Where |
|------|-------|
| Remembered server | `defaults read com.plosson.siteio-companion serverURL` |
| Session cookie | WebKit's default data store (`~/Library/WebKit/com.plosson.siteio-companion`) |

## Bridge

The admin page (main frame, server's own origin only) gets:

```ts
window.siteioCompanion = {
  present: true,          // the page lays itself out for the window (siteio's ui.js adds the .app class)
  dragWindow(): void,     // a press on empty chrome moves the window
}
```

It exposes no shell, keys or file APIs. Links to other origins (a site, the live editor) open in the browser.

## License

Private / TBD — © Pierre A. Losson
