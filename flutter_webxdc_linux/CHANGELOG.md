## 0.0.1

* Replace the "open in browser" fallback with a real, embedded,
  JS-bridged WebView host, using
  [`flutter_inappwebview_forge`](https://pub.dev/packages/flutter_inappwebview_forge)
  (a drop-in-API-compatible fork of `flutter_inappwebview` whose
  `flutter_inappwebview_forge_linux` backend is built on WPE WebKit),
  chosen over the official `flutter_inappwebview` package (whose Linux
  support is only available in a `6.2.0`-series prerelease/beta) for API
  stability. `LinuxWebxdcPlatform` now mirrors
  `flutter_webxdc_webview`'s `WebviewWebxdcPlatform` almost line-for-line:
  it injects `window.webxdc` via an `AT_DOCUMENT_START` `UserScript`,
  bridges `sendUpdate`/`setUpdateListener`/`sendToChat`/`importFiles`
  through `addJavaScriptHandler`/`callHandler`/`evaluateJavascript`,
  queues updates until the `InAppWebViewController` exists, and adds a
  `WebxdcFilePicker`-based `importFiles` backed by `file_selector` by
  default (previously always returned an empty list). Removed the
  `url_launcher` dependency and the `UrlOpener`/"open in browser"
  affordance it's no longer needed for.
* Building/running this package on Linux now requires the system WPE
  WebKit runtime and dev packages (`wpe-webkit-2.0`/`1.1`/`1.0`,
  `wpe-platform-2.0` or `wpebackend-fdo-1.0`, `libwpe-1.0`, `epoxy`,
  `gtk+-3.0` via pkg-config) to be installed; see `README.md` and
  `doc/design.md` for the exact package names and the honest disclosure
  that `flutter build linux` could not be verified in this sandbox since
  those system libraries aren't installed here (only `flutter pub get`,
  `dart format`, `flutter analyze`, and `flutter test` were run).
* Rewrote `test/linux_webxdc_platform_test.dart` (real loopback
  `HttpServer`/`HttpClient` coverage of `loadApp`/`sendToChat`/
  `importFiles`/`deliverUpdateToApp`/`disposeApp`, including both
  `request_internet_access` CSP states) and
  `test/linux_webxdc_platform_widget_test.dart` (construction of the real
  `buildHostWidget`/`buildWebView` and update-queuing behavior, using a
  minimal fake `InAppWebViewPlatform` since a real native WPE WebKit
  engine is not available under plain `flutter test`).
* Initial Linux implementation of `flutter_webxdc`'s `WebxdcPlatform`
  contract. Hosted `.xdc` assets over a real loopback HTTP server (shared
  `WebxdcLocalServer` with `flutter_webxdc_webview`) and exposed an
  explicit "open in browser" host widget instead of an embedded WebView,
  since `flutter_inappwebview` did not support Linux at the time. See
  `doc/design.md` for the full rationale and known limitations.
