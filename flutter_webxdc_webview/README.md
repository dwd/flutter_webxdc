# flutter_webxdc_webview

Native platforms implementation of the [`flutter_webxdc`](../README.md)
`WebxdcPlatform` contract, utilizing `flutter_inappwebview`.

It is designed to be the default implementation for Android, iOS, macOS, and Windows.

It:
- creates a local `HttpServer` to serve the extracted `.xdc` in-memory assets dynamically;
- attaches a `UserScript` to inject the messenger-owned `window.webxdc` shim;
- forwards JS update/chat calls to Dart using the custom JavaScript handler `callHandler`;
- applies an initial `Content-Security-Policy` header blocking network access unless `request_internet_access = true`.

After opening a `WebxdcSession`, a host native app can render the `.xdc` by attaching the created WebView widget:

```dart
import 'package:flutter_webxdc/flutter_webxdc.dart';
import 'package:flutter_webxdc_webview/flutter_webxdc_webview.dart';

final session = await WebxdcSession.open(/* ... */);
final webviewPlatform = WebxdcPlatform.instance as WebviewWebxdcPlatform;

// Attach the WebView to the widget tree:
Widget build(BuildContext context) {
  return webviewPlatform.buildWebView(session.instanceId);
}
```

## Limitations
This is an initial integration using `flutter_inappwebview`. Advanced features like `sendToChat` file payload forwarding, and dynamic deep linking remain for follow-up work.
