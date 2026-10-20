# siteio Companion

Native macOS app (Swift, SwiftUI) for a [siteio](https://github.com/plosson/siteio) server: one window that shows the server's admin page (`https://api.<domain>/ui`), as AgentIO Companion does for an agentio hub.

The admin page is the server's own: new siteio features need no app update. You sign in on that page (username and password, or the API key); the session cookie is kept between launches.

## Build, test and run

```bash
cd apps/macos
xcodegen generate                       # creates SiteioCompanion.xcodeproj (not committed)
xcodebuild -scheme SiteioCompanion -destination 'platform=macOS' -derivedDataPath build test
xcodebuild -scheme SiteioCompanion -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/siteio.app
```

Requirements: macOS 14 or later, Xcode 26, XcodeGen (`brew install xcodegen`), and a siteio agent 1.50.0 or later (the version whose admin page knows the bridge).

Against a local agent, Debug builds accept `http://localhost:<port>` or `http://127.0.0.1:<port>`; Release builds accept https only. One test drives a real admin page and is skipped unless you name one:

```bash
TEST_RUNNER_SITEIO_DEV_URL="http://127.0.0.1:3000/ui?key=<api key>" xcodebuild -scheme SiteioCompanion -destination 'platform=macOS' -derivedDataPath build test
```

## Where the app keeps things

| What | Where |
|------|-------|
| Remembered server | `defaults read com.plosson.siteio-companion serverURL` |
| Session cookie | WebKit's default data store, in the app's sandbox container |

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
