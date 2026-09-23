## 0.0.1 (In Development)

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
* Federated platform packages (`flutter_webxdc_platform_interface`,
  per-platform Android/Desktop/Web hosting) are still not implemented; see
  `doc/design.md` for the target architecture.

* Initial design documentation (`doc/design.md`) and basic test fixtures
  (`test/fixtures/`) added to define the target federated plugin architecture,
  JS bridge contract, and manifest schema.
