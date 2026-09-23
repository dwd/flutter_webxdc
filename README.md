<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# flutter_webxdc

A Flutter plugin that implements the [webxdc specification](https://webxdc.org/docs/spec/index.html)
to enable interactive, embeddable mini apps (`.xdc` archives) in Flutter applications.

## Status

This repository implements the federated package split described in
[doc/design.md](doc/design.md#2-target-federated-package-layout) up through a
runnable in-memory platform backend. It targets the following platforms once
per-platform WebView/iframe hosting is implemented:
- **Android**
- **Desktop** (Linux, macOS, Windows)
- **Web**

Packages that exist today:
- **`flutter_webxdc`** (this package) — the app-facing API:
  - `WebxdcManifest` — `manifest.toml` parsing (`fromToml`/`fromMap`).
  - `WebxdcArchive` — read-only `.xdc` zip container reader with zip-slip
    protection.
  - `WebxdcController` — per-instance update log/replay API.
  - `WebxdcSession` / `FlutterWebxdc` — wires the shared core to a registered
    `WebxdcPlatform` (load app, forward updates, dispose).
- **[`flutter_webxdc_platform_interface`](flutter_webxdc_platform_interface/README.md)**
  — the stable Dart contract per-platform packages must implement:
  - `WebxdcUpdate`, `WebxdcImportedFile`, JS-bridge event types.
  - `WebxdcPlatform` — hosting, updates, `sendToChat`, `importFiles`,
    realtime-channel capability detection, and JS→host event streams.
- **[`flutter_webxdc_memory`](flutter_webxdc_memory/README.md)** — the first
  concrete `WebxdcPlatform` implementation. Hosts `.xdc` assets and the
  update bridge entirely in memory (no WebView/browser), registers via
  `MemoryWebxdcPlatform.registerWith()`, and is the default backend
  auto-installed by `FlutterWebxdc.ensureInitialized()`.

Not implemented yet: the five native/Web platform packages
(`flutter_webxdc_android`, `_linux`, `_macos`, `_windows`, `_web`),
`flutter_inappwebview`/web-iframe hosting, and real JS injection. For the
detailed architecture and roadmap, please see [doc/design.md](doc/design.md).

## Usage

```dart
import 'package:flutter_webxdc/flutter_webxdc.dart';

// Optional: auto-registers MemoryWebxdcPlatform when nothing else is set.
FlutterWebxdc.ensureInitialized();

final session = await WebxdcSession.open(
  xdcBytes: xdcZipBytes,
  instanceId: 'chat-msg-42',
  selfAddr: 'me@example',
  selfName: 'Me',
);

// Host transports peer updates in/out via the session:
session.updates.listen((update) {
  // Send `update` to other chat peers over your own transport.
});
session.sendUpdate({'payload': {'counter': 1}, 'info': 'bumped'});
session.deliverPeerUpdate({'payload': {'counter': 2}}); // from a peer

await session.dispose();
```

Native WebView / iframe hosting is not available yet; `WebxdcSession` runs
against `MemoryWebxdcPlatform` by default so the full plugin path is
testable today. See [doc/design.md](doc/design.md) for the planned
platform packages.

## Additional information

Please refer to [doc/design.md](doc/design.md) for the target architecture,
the JS API contract, and testing strategy. Contributions are welcome for the
remaining federated platform packages (`flutter_webxdc_android`, `_linux`,
`_macos`, `_windows`, `_web`), which should mirror
[`flutter_webxdc_memory`](flutter_webxdc_memory/README.md)'s structure
(`registerWith()`, extends `WebxdcPlatform`, emits JS-bridge events) while
swapping the in-memory host for a real WebView or iframe bridge.
