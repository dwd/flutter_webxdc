## 0.0.1 (In Development)

* Add `flutter_webxdc_linux/`, a real Linux `WebxdcPlatform` implementation,
  registered as the root package's `default_package` for `linux`.
  `flutter_inappwebview` does not support Linux and no other maintained,
  embeddable Linux WebView plugin exists today, so instead of leaving Linux
  unimplemented, `flutter_webxdc_linux` hosts `.xdc` assets over the same
  loopback HTTP server used by `flutter_webxdc_webview`, and its
  `buildHostWidget` surfaces an explicit, injectable "open in browser"
  action (`url_launcher`) rather than a silent placeholder or a fake
  embedded renderer. `sendToChat` is real (validates + emits shared
  events); `importFiles` currently always returns an empty list (no native
  Linux picker yet). There is intentionally **no live `window.webxdc` JS
  bridge** on this platform, since the app runs in an external browser tab
  — documented as the primary, honest limitation rather than hidden.
* Extract `WebxdcServer` out of `flutter_webxdc_webview` into
  `flutter_webxdc_platform_interface` as the shared `WebxdcLocalServer`, so
  both `flutter_webxdc_webview` and the new `flutter_webxdc_linux` reuse one
  loopback-HTTP-host/CSP implementation instead of duplicating it.
  `flutter_webxdc_webview`'s `WebxdcServer` is kept as a backward-compatible
  type alias so existing imports/tests are unaffected.
* Add `flutter_webxdc_linux/test/linux_webxdc_platform_test.dart` (real
  loopback `HttpServer`/`HttpClient` coverage of `loadApp`/`sendToChat`/
  `importFiles`/`deliverUpdateToApp`/`disposeApp`, including the
  `request_internet_access` CSP contract) and
  `linux_webxdc_platform_widget_test.dart` (a `tester.runAsync`-based widget
  test of `buildHostWidget`'s "open in browser" affordance with an injected
  `UrlOpener`).
* Update `README.md` and `doc/design.md` to document `flutter_webxdc_linux`
  as an implemented platform with its real capabilities and its one
  intentional, disclosed limitation (no embedded JS bridge), instead of
  Linux being entirely absent from the target-platform list.
* Expose a backend-agnostic render surface through the shared/root API:
  `WebxdcPlatform` now defines `buildHostWidget(instanceId)`, `WebxdcSession`
  exposes `buildHostWidget()` plus `sendToChatRequests`, and the root package
  adds `WebxdcHostView` as a thin declarative wrapper. `flutter_webxdc_web`
  now implements this contract with `HtmlElementView`, `flutter_webxdc_webview`
  implements it with a deferred `InAppWebView` host widget, and the memory
  backend provides a placeholder render surface for test/Linux fallback.
* Replace the obvious native `flutter_webxdc_webview` stubs with real behavior:
  `sendToChat` now validates and emits shared `WebxdcJsSendToChatEvent`s,
  `importFiles` now uses `file_selector` 1.0.3, JS `sendToChat` parsing now
  supports file payload metadata/bytes, and updates delivered before the
  `InAppWebViewController` exists are queued instead of being dropped.
* Add regression coverage for the new shared render contract and native/web
  behavior: root `WebxdcSession` tests cover `sendToChatRequests` and host
  widget/session surfaces; `flutter_webxdc_webview` tests cover queued native
  updates plus real `sendToChat`/`importFiles`; `flutter_webxdc_web` adds a
  browser-scoped `buildHostWidget` test.
* Fix `flutter_webxdc_webview`'s `WebxdcServer` Content-Security-Policy so
  `request_internet_access = true` actually widens `connect-src`/`img-src`/
  `media-src`/`frame-src` to allow `https:`/`wss:` origins, instead of
  leaving external network access blocked regardless of the manifest flag.
  The policy is now built by a dedicated, unit-testable
  `WebxdcServer.buildContentSecurityPolicy(bool)`. Added
  `test/webxdc_server_test.dart` in `flutter_webxdc_webview`, exercising the
  loopback server directly over `HttpClient` (no device/browser): the
  `/` → `index.html` rewrite, content-type mapping, 404 handling, and the
  CSP header for both `request_internet_access` states.
* Correct `doc/design.md` and `README.md` to accurately describe
  `flutter_webxdc_webview` as implemented (native `flutter_inappwebview`
  host for Android/iOS/macOS/Windows, no Linux support) instead of still
  claiming native platform packages don't exist; also documented its real
  remaining gaps (`sendToChat`/`importFiles` stubs, `buildWebView` not yet
  part of the shared `WebxdcPlatform` interface, updates dropped before the
  WebView controller is created).
* Add `flutter_webxdc_webview/`, the initial real native platform package utilizing `flutter_inappwebview`.
  The root package declares it as its default package for Android, iOS, macOS, and Windows. 
  It creates a local `HttpServer` loopback to dynamically serve extracted `.xdc` assets, 
  and injects the `window.webxdc` JS bridge.
* Add `flutter_webxdc_web/`, the initial real Flutter Web platform package.
  The root package declares it as its Web `default_package`, so Flutter's
  plugin registrant installs `WebWebxdcPlatform`. It hosts apps in sandboxed
  `srcdoc` iframes, injects the messenger-owned `window.webxdc` shim, and
  authenticates JSON `postMessage` traffic with both iframe source and a
  per-instance token. It supports update replay, JS→host update/chat events,
  and browser file import; see `doc/design.md` for its deliberate asset and
  file-payload limitations.
* Correct `WebxdcSession`'s asynchronous-delivery comment: an unawaited
  `deliverUpdateToApp` failure does not reach the controller stream
  subscription's `onError`; platform implementations must queue/handle
  delivery failures until the public session error contract is expanded.
* Wired the root package to `WebxdcPlatform` and added the first concrete
  platform implementation package:
  - `flutter_webxdc_memory/` — in-memory `MemoryWebxdcPlatform` that hosts
    `.xdc` file trees and the update/`sendToChat`/`importFiles` bridge
    without a WebView or browser. Registers via
    `MemoryWebxdcPlatform.registerWith()` and is the default backend
    installed by `FlutterWebxdc.ensureInitialized()`.
  - `WebxdcSession` / `FlutterWebxdc` in the root package — open a `.xdc`
    zip against the registered platform, forward controller updates into
    `deliverUpdateToApp`, and record JS-originated `sendUpdate` events.
  - Platform interface gained JS→host event streams
    (`sendUpdateEvents` / `sendToChatEvents`) and the matching event
    types so every platform package has a uniform way to surface mini-app
    JS calls to the host.
* Started the federated package split described in `doc/design.md` §2:
  added `flutter_webxdc_platform_interface/` (a real, separately
  `pub get`-able package) holding `WebxdcUpdate` (moved out of
  `flutter_webxdc`) and the abstract `WebxdcPlatform` contract (built
  on `package:plugin_platform_interface`, `PlatformInterface` + static
  `instance` pattern). The root `flutter_webxdc` package depends on it
  via a local path dependency and re-exports it from
  `lib/flutter_webxdc.dart`. Both `pubspec.yaml`s are marked
  `publish_to: none` while developed together in this repo.
* Implemented the shared, platform-agnostic core described in
  `doc/design.md`: `WebxdcManifest` (`manifest.toml` parsing), `WebxdcArchive`
  (read-only `.xdc` zip reader with zip-slip protection), `WebxdcUpdate`
  (the `sendUpdate`/`setUpdateListener` payload model), and
  `WebxdcController` (app-facing update log/replay API). Promoted `toml` to
  a runtime dependency and added `archive` for `.xdc` zip reading. Replaced
  the placeholder `Calculator` class in `lib/flutter_webxdc.dart`.
* Corrected `doc/design.md` to say `manifest.toml` is optional and
  `index.html` mandatory in a `.xdc` archive, matching the upstream format
  spec and the new `WebxdcArchive` reader (previously documented as the
  reverse).
* Initial design documentation (`doc/design.md`) and basic test fixtures
  (`test/fixtures/`) added to define the target federated plugin architecture,
  JS bridge contract, and manifest schema.
