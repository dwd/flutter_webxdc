## 0.0.1 (In Development)

* Wired the root package to `WebxdcPlatform` and added the first concrete
  platform implementation package:
  - `flutter_webxdc_memory/` — in-memory `MemoryWebxdcPlatform` that hosts
    `.xdc` file trees and the update/`sendToChat`/`importFiles` bridge
    without a WebView or browser. Registers via
    `MemoryWebxdcPlatform.registerWith()` and is the default backend
    installed by `FlutterWebxdc.ensureInitialized()`.
  - `WebxdcSession` / `FlutterWebxdc` in the root package — open a `.xdc`
    zip against the registered platform, forward controller updates into
    `deliverUpdateToApp`, and record JS-originated `sendUpdate` events.
  - Platform interface gained JS→host event streams
    (`sendUpdateEvents` / `sendToChatEvents`) and the matching event
    types so every platform package has a uniform way to surface mini-app
    JS calls to the host.
* Started the federated package split described in `doc/design.md` §2:
  added `flutter_webxdc_platform_interface/` (a real, separately
  `pub get`-able package) holding `WebxdcUpdate` (moved out of
  `flutter_webxdc`) and the abstract `WebxdcPlatform` contract (built
  on `package:plugin_platform_interface`, `PlatformInterface` + static
  `instance` pattern). The root `flutter_webxdc` package depends on it
  via a local path dependency and re-exports it from
  `lib/flutter_webxdc.dart`. Both `pubspec.yaml`s are marked
  `publish_to: none` while developed together in this repo.
* Implemented the shared, platform-agnostic core described in
  `doc/design.md`: `WebxdcManifest` (`manifest.toml` parsing), `WebxdcArchive`
  (read-only `.xdc` zip reader with zip-slip protection), `WebxdcUpdate`
  (the `sendUpdate`/`setUpdateListener` payload model), and
  `WebxdcController` (app-facing update log/replay API). Promoted `toml` to
  a runtime dependency and added `archive` for `.xdc` zip reading. Replaced
  the placeholder `Calculator` class in `lib/flutter_webxdc.dart`.
* Corrected `doc/design.md` to say `manifest.toml` is optional and
  `index.html` mandatory in a `.xdc` archive, matching the upstream format
  spec and the new `WebxdcArchive` reader (previously documented as the
  reverse).
* Native Android/Desktop/Web hosting packages (`flutter_webxdc_android`,
  `_linux`, `_macos`, `_windows`, `_web`) and real JS injection are still
  not implemented; see `doc/design.md` for the target architecture.
* Initial design documentation (`doc/design.md`) and basic test fixtures
  (`test/fixtures/`) added to define the target federated plugin architecture,
  JS bridge contract, and manifest schema.
