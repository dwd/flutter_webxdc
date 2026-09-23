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

This repository has started the federated package split described in
[doc/design.md](doc/design.md#2-target-federated-package-layout); no web
view/iframe hosting exists yet. It targets the following platforms once
per-platform hosting is implemented:
- **Android**
- **Desktop** (Linux, macOS, Windows)
- **Web**

Two packages exist today:
- **`flutter_webxdc`** (this package) — the app-facing API, re-exporting
  the platform-interface package below so most consumers only need this
  dependency:
  - `WebxdcManifest` — `manifest.toml` parsing (`fromToml`/`fromMap`).
  - `WebxdcArchive` — read-only `.xdc` zip container reader with zip-slip
    protection.
  - `WebxdcController` — the app-facing update log/replay API a
    `WebxdcPlatform` implementation would sit on top of.
- **[`flutter_webxdc_platform_interface`](flutter_webxdc_platform_interface/README.md)**
  — the stable Dart contract per-platform packages must implement:
  - `WebxdcUpdate` — the `sendUpdate`/`setUpdateListener` JS-bridge payload
    model.
  - `WebxdcPlatform` — the abstract platform contract (hosting, updates,
    `sendToChat`, `importFiles`, realtime-channel capability detection).
    No platform package implements it yet.

Not implemented yet: the five per-platform packages
(`flutter_webxdc_android`, `_linux`, `_macos`, `_windows`, `_web`),
`flutter_inappwebview`/web-iframe hosting, and JS injection. For the
detailed architecture and roadmap, please see [doc/design.md](doc/design.md).

## Usage

```dart
import 'package:flutter_webxdc/flutter_webxdc.dart';

final archive = WebxdcArchive.fromBytes(xdcZipBytes);
final manifest = archive.manifest; // may be null; manifest.toml is optional

final controller = WebxdcController(selfAddr: 'me@example', selfName: 'Me');
controller.updates.listen((update) {
  // Forward to mini-app JS's setUpdateListener callback.
});
controller.sendUpdate({'payload': {'counter': 1}});
```

Full web view/iframe hosting is not available yet; see
[doc/design.md](doc/design.md) for the planned platform packages.

## Additional information

Please refer to [doc/design.md](doc/design.md) for the target architecture,
the JS API contract, and testing strategy. Contributions are welcome for the
remaining federated platform packages (`flutter_webxdc_android`, `_linux`,
`_macos`, `_windows`, `_web`), which would depend on
[`flutter_webxdc_platform_interface`](flutter_webxdc_platform_interface/README.md)
and implement its `WebxdcPlatform` contract.
