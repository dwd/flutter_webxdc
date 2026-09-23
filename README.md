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
[doc/design.md](doc/design.md#2-target-federated-package-layout) providing an in-memory backend, a native platform integration using `flutter_inappwebview` (`flutter_webxdc_webview`), and an initial Flutter Web iframe host (`flutter_webxdc_web`). 

It targets the following platforms:
- **Android**, **iOS**, **macOS**, **Windows** — via `flutter_webxdc_webview`
  (`flutter_inappwebview`-based native hosting).
- **Web** — via `flutter_webxdc_web` (sandboxed iframe + `postMessage`
  hosting).
- **Linux** is not yet covered: `flutter_inappwebview` does not support it;
  see [doc/design.md](doc/design.md#2-target-federated-package-layout) for
  the follow-up plan.

Packages that exist today:
- **`flutter_webxdc`** (this package) — the app-facing API:
  - `WebxdcManifest` — `manifest.toml` parsing (`fromToml`/`fromMap`).
  - `WebxdcArchive` — read-only `.xdc` zip container reader with zip-slip
    protection.
  - `WebxdcController` — per-instance update log/replay API.
  - `WebxdcSession` / `FlutterWebxdc` — wires the shared core to a registered
    `WebxdcPlatform` (load app, forward updates, expose `sendToChat` requests,
    render, dispose).
- **[`flutter_webxdc_platform_interface`](flutter_webxdc_platform_interface/README.md)**
  — the stable Dart contract per-platform packages must implement:
  - `WebxdcUpdate`, `WebxdcImportedFile`, JS-bridge event types.
  - `WebxdcPlatform` — hosting, updates, `sendToChat`, `importFiles`,
    realtime-channel capability detection, and JS→host event streams.
- **[`flutter_webxdc_memory`](flutter_webxdc_memory/README.md)** — the first
  concrete `WebxdcPlatform` implementation. Hosts `.xdc` assets and the
  update bridge entirely in memory (no WebView/browser).
- **[`flutter_webxdc_web`](flutter_webxdc_web/README.md)** — initial Web
  `WebxdcPlatform` implementation, registered automatically through the root
  package's Flutter Web plugin metadata.
- **[`flutter_webxdc_webview`](flutter_webxdc_webview/README.md)** — native `WebxdcPlatform` implementation utilizing `flutter_inappwebview`, supporting Android, iOS, macOS, and Windows. It injects the `window.webxdc` JS bridge and dynamically serves extracted archive content through a local `HttpServer` loopback.

Not implemented yet: a Linux native host (`flutter_inappwebview` does not
support Linux), broader Web asset virtualization (CSS `url(...)`, dynamic
imports, service workers), Web JS `sendToChat` file-payload forwarding, and
native/device-level verification of the `flutter_inappwebview` runtime path in
this repository. See [doc/design.md](doc/design.md) for the detailed
architecture, current limitations, and roadmap.

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
session.sendToChatRequests.listen((request) {
  // Open your host app's compose/share UI for request.text / request.fileBytes.
});

Widget build(BuildContext context) {
  return session.buildHostWidget();
  // Or: return WebxdcHostView(session: session);
}

session.sendUpdate({'payload': {'counter': 1}, 'info': 'bumped'});
session.deliverPeerUpdate({'payload': {'counter': 2}}); // from a peer

await session.dispose();
```

On Flutter Web the plugin registrant installs `WebWebxdcPlatform`; on
Android/iOS/macOS/Windows it installs `WebviewWebxdcPlatform`
(`flutter_webxdc_webview`). In both cases the root API now exposes the render
surface directly through `session.buildHostWidget()` / `WebxdcHostView`, so no
backend-specific cast is required just to display the app. If neither platform
package registers itself (e.g. on Linux, or in plain `flutter test` runs),
`WebxdcSession` falls back to `MemoryWebxdcPlatform`, which renders a
non-interactive placeholder while keeping the full shared plugin path testable
without a device/browser. See [doc/design.md](doc/design.md),
[flutter_webxdc_web/README.md](flutter_webxdc_web/README.md), and
[flutter_webxdc_webview's README](flutter_webxdc_webview/README.md) for
platform-specific details.

## Additional information

Please refer to [doc/design.md](doc/design.md) for the target architecture,
the JS API contract, and testing strategy. Contributions are welcome for a
Linux native host and for closing the remaining Web hardening/runtime-test gaps
in [`flutter_webxdc_web`](flutter_webxdc_web/README.md) and
[`flutter_webxdc_webview`](flutter_webxdc_webview/README.md); new platform
packages should mirror
[`flutter_webxdc_memory`](flutter_webxdc_memory/README.md)'s structure
(`registerWith()`, extends `WebxdcPlatform`, emits JS-bridge events).
