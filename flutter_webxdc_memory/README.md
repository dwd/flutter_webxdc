# flutter_webxdc_memory

In-memory platform implementation of the
[`flutter_webxdc`](../README.md) `WebxdcPlatform` contract.

This package hosts `.xdc` assets and the update / file-import /
`sendToChat` bridge **without** a real WebView or browser, so the full
federated plugin path (root package → platform interface → platform
package) can be exercised under plain `flutter test`. It is also the
default backend auto-registered by `FlutterWebxdc.ensureInitialized()`
until a native or Web platform package takes over.

Future packages (`flutter_webxdc_android`, `flutter_webxdc_web`, ...)
should mirror this package's structure (`registerWith()`, extends
`WebxdcPlatform`, emits `sendUpdateEvents` / `sendToChatEvents`) while
swapping the in-memory host for `flutter_inappwebview` or an iframe /
`postMessage` bridge — see
[`doc/design.md`](../doc/design.md#2-target-federated-package-layout).

## Usage

```dart
import 'package:flutter_webxdc_memory/flutter_webxdc_memory.dart';

// Register as the active WebxdcPlatform implementation.
MemoryWebxdcPlatform.registerWith();

// Or, let the app-facing package do it:
// FlutterWebxdc.ensureInitialized();
```
