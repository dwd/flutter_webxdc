# flutter_webxdc_webview

Native platforms implementation of the [`flutter_webxdc`](../README.md)
`WebxdcPlatform` contract, utilizing `flutter_inappwebview`.

It is designed to be the default implementation for Android, iOS, macOS, and Windows.

It:
- creates a local `HttpServer` to serve the extracted `.xdc` in-memory assets dynamically;
- attaches a `UserScript` to inject the messenger-owned `window.webxdc` shim;
- forwards JS update/chat calls to Dart using the custom JavaScript handler `callHandler`;
- applies an initial `Content-Security-Policy` header blocking network access unless `request_internet_access = true`.

After opening a `WebxdcSession`, a host native app can render the `.xdc`
through the shared root-package widget API:

```dart
import 'package:flutter_webxdc/flutter_webxdc.dart';

final session = await WebxdcSession.open(/* ... */);

Widget build(BuildContext context) {
  return session.buildHostWidget();
  // Or: return WebxdcHostView(session: session);
}
```

`WebviewWebxdcPlatform.buildWebView(instanceId)` remains available as a
package-specific escape hatch, but ordinary hosts no longer need to cast just
to obtain a renderable `Widget`.

## Limitations

This is an initial integration using `flutter_inappwebview`. Remaining gaps are
runtime/device verification of the real native WebView path in this repository,
dynamic deep linking, and the fact that `file_selector`-based imports may still
need platform entitlements/configuration in embedding apps (for example macOS
user-selected file access). See [`doc/design.md`](../doc/design.md) for the
broader security boundary and roadmap.
