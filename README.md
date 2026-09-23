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

This plugin currently provides the platform-agnostic shared core only; no
web view/iframe hosting exists yet. It targets the following platforms once
per-platform hosting is implemented:
- **Android**
- **Desktop** (Linux, macOS, Windows)
- **Web**

Implemented today, in `lib/flutter_webxdc.dart`:
- `WebxdcManifest` — `manifest.toml` parsing (`fromToml`/`fromMap`).
- `WebxdcArchive` — read-only `.xdc` zip container reader with zip-slip
  protection.
- `WebxdcUpdate` — the `sendUpdate`/`setUpdateListener` JS-bridge payload
  model.
- `WebxdcController` — the app-facing update log/replay API a future JS
  bridge would sit on top of.

Not implemented yet: the federated `flutter_webxdc_platform_interface` and
per-platform packages, `flutter_inappwebview`/web-iframe hosting, and JS
injection. For the detailed architecture and roadmap, please see
[doc/design.md](doc/design.md).

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
remaining federated platform packages.
