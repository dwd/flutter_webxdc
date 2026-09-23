## 0.0.1 (In Development)

* Add the initial `flutter_inappwebview`-based native `WebxdcPlatform` implementation for Android, iOS, macOS, and Windows. It creates a local `HttpServer` loopback to serve the extracted `.xdc` assets dynamically to bypass CORS issues, and injects the `window.webxdc` JS bridge.
