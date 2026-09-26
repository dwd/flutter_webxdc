# flutter_webxdc_linux

Linux implementation of `flutter_webxdc`'s `WebxdcPlatform` contract. See
`doc/design.md` in the `flutter_webxdc` repository for the full target
architecture.

## Why this package looks different from `flutter_webxdc_webview`

The official `flutter_inappwebview` package (the WebView technology
`flutter_webxdc_webview` uses for Android/iOS/macOS/Windows) only gained
Linux support in a `6.2.0`-series prerelease/beta, which is too unstable
an API surface to depend on here. Instead, this package uses
[`flutter_inappwebview_forge`](https://pub.dev/packages/flutter_inappwebview_forge),
a drop-in-API-compatible fork of `flutter_inappwebview` that ships a real
native Linux backend (`flutter_inappwebview_forge_linux`) built on
[WPE WebKit](https://wpewebkit.org/). It exposes the exact same class
names/JS bridge global (`InAppWebView`, `InAppWebViewController`,
`UserScript`, `window.flutter_inappwebview.callHandler`, …) as the
official package, so the native bridge code below mirrors
`flutter_webxdc_webview`'s `WebviewWebxdcPlatform` almost line-for-line:

* `loadApp` hosts the extracted `.xdc` file tree over a genuine loopback
  HTTP server (`WebxdcLocalServer`, shared with `flutter_webxdc_webview`),
  enforcing the same `request_internet_access` Content-Security-Policy
  contract as the other native hosts.
* `buildHostWidget`/`buildWebView` return a real, embedded `InAppWebView`
  with an injected `window.webxdc` JS shim, bridged through
  `addJavaScriptHandler`/`callHandler`/`evaluateJavascript`. Updates
  delivered before the underlying `InAppWebViewController` exists are
  queued and flushed once it is created.
* `sendToChat` validates and emits shared `WebxdcJsSendToChatEvent`s, and
  `importFiles` uses a real, injectable file picker backed by
  `file_selector` by default.

## System dependency: WPE WebKit

Unlike Android/iOS/macOS/Windows, actually building and running this
package on Linux requires the WPE WebKit runtime and its development
headers to be installed on the build machine. `flutter_inappwebview_forge_linux`'s
native `linux/CMakeLists.txt` locates these via `pkg-config`:

* `wpe-webkit-2.0` (falling back to `wpe-webkit-1.1`/`wpe-webkit-1.0`)
* `wpe-platform-2.0` (falling back to `wpebackend-fdo-1.0`)
* `libwpe-1.0`
* `epoxy`
* `gtk+-3.0`

On Debian/Ubuntu-family distributions these are typically available as
`libwpewebkit-2.0-dev` (or the `-1.1`/`-1.0` equivalents for older
distributions), `libwpe-1.0-dev`, `libepoxy-dev`, and `libgtk-3-dev` (exact
package names vary by distribution/version). **These packages are not
installed in this repository's sandboxed development/test environment**,
so while the Dart-level unit/widget tests in `test/` run under plain
`flutter test`, `flutter build linux` cannot be verified from this
environment — see `doc/design.md` for the honest disclosure of this gap.
Anyone building this package for a real Linux target must install the
system packages above first.

## Testing

`test/linux_webxdc_platform_test.dart` exercises `loadApp`/`sendToChat`/
`importFiles`/`deliverUpdateToApp`/`disposeApp` against the real loopback
`WebxdcLocalServer` (including the `request_internet_access` CSP
contract), and `test/linux_webxdc_platform_widget_test.dart` exercises
`buildHostWidget`/`buildWebView`'s construction and update-queuing
behavior using a minimal fake `InAppWebViewPlatform` (since a real WPE
WebKit engine is not available under plain `flutter test`, the same way
`flutter_webxdc_webview`'s tests don't require a real native WebView
either).
