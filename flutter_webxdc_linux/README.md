# flutter_webxdc_linux

Linux implementation of `flutter_webxdc`'s `WebxdcPlatform` contract. See
`doc/design.md` in the `flutter_webxdc` repository for the full target
architecture.

## Why this package looks different from `flutter_webxdc_webview`

`flutter_inappwebview` (the WebView technology `flutter_webxdc_webview`
uses for Android/iOS/macOS/Windows) does **not** support Linux, and there
is no other maintained, embeddable in-app WebView plugin for Linux this
repository can depend on today. Rather than leaving Linux entirely
unimplemented (which is what happened before this package existed), this
package still does real, testable work:

* `loadApp` hosts the extracted `.xdc` file tree over a genuine loopback
  HTTP server (`WebxdcLocalServer`, shared with `flutter_webxdc_webview`),
  enforcing the same `request_internet_access` Content-Security-Policy
  contract as the native hosts.
* `buildHostWidget` returns an explicit widget that surfaces the served
  URL and an "Open in browser" action (`url_launcher`), instead of a
  silent placeholder or a fake embedded renderer.

## Known limitation: no live JS bridge

Because the app is opened in an external browser tab rather than an
embedded, JS-bridged surface, **`window.webxdc` is never injected there**:
`sendUpdate`/`setUpdateListener` calls made by a mini app opened this way
are not observed by this platform. `sendToChat` and `importFiles` are
still available as host-driven operations (e.g. so a host app's own
chat/file UI can call them programmatically) and are recorded via
`sendToChatLog`/`sendToChatEvents` exactly like `flutter_webxdc_memory`,
but `importFiles` currently always returns an empty list on Linux (no
native file-picker integration is wired up yet).

If/when a maintained, embeddable Linux WebView implementation becomes
available (e.g. via `webview_flutter_linux` reaching a stable, buildable
state, or an alternative), this package is the natural place to add real
in-app hosting with a live JS bridge, superseding the "open in browser"
fallback described above.
