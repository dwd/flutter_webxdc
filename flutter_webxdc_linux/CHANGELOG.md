## 0.0.1

* Initial Linux implementation of `flutter_webxdc`'s `WebxdcPlatform`
  contract. Hosts `.xdc` assets over a real loopback HTTP server (shared
  `WebxdcLocalServer` with `flutter_webxdc_webview`) and exposes an
  explicit "open in browser" host widget instead of an embedded WebView,
  since `flutter_inappwebview` does not support Linux. See
  `doc/design.md` for the full rationale and known limitations.
