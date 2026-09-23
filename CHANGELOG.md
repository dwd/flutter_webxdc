## 0.0.1 (In Development)

* Started the federated package split described in `doc/design.md` §2:
  added `flutter_webxdc_platform_interface/` (a real, separately
  `pub get`-able package) holding `WebxdcUpdate` (moved out of
  `flutter_webxdc`) and the new abstract `WebxdcPlatform` contract (built
  on `package:plugin_platform_interface`, `PlatformInterface` + static
  `instance` pattern; every method throws `UnimplementedError` by default
  since no platform package implements it yet). The root `flutter_webxdc`
  package now depends on it via a local path dependency and re-exports it
  from `lib/flutter_webxdc.dart`, so existing public-API usages
  (`WebxdcUpdate`, `WebxdcController`, etc.) are unaffected. Both
  `pubspec.yaml`s are marked `publish_to: none` while developed together
  in this repo. `flutter_webxdc_android`/`_linux`/`_macos`/`_windows`/`_web`
  still do not exist.
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
* Per-platform Android/Desktop/Web hosting packages are still not
  implemented (only `flutter_webxdc_platform_interface` exists so far, see
  above); see `doc/design.md` for the target architecture.

* Initial design documentation (`doc/design.md`) and basic test fixtures
  (`test/fixtures/`) added to define the target federated plugin architecture,
  JS bridge contract, and manifest schema.
