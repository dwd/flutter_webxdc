/// Platform-agnostic Dart API for implementing the
/// [webxdc specification](https://webxdc.org/docs/spec/index.html).
///
/// See `doc/design.md` for the full target architecture. This library
/// exposes the app-facing half of the federated package layout described
/// there (§2): `manifest.toml` parsing ([WebxdcManifest]), the `.xdc` zip
/// container reader ([WebxdcArchive]), and the app-facing update log/replay
/// controller ([WebxdcController]).
///
/// It also re-exports the stable platform contract from
/// `flutter_webxdc_platform_interface` ([WebxdcUpdate], [WebxdcPlatform],
/// [WebxdcImportedFile]) so most consumers only need to depend on this
/// package.
///
/// Platform hosting (Android/Desktop `flutter_inappwebview` web views, the
/// Web `<iframe>`/`postMessage` bridge) is not yet implemented; per
/// `doc/design.md` §2 those live in dedicated per-platform packages
/// (`flutter_webxdc_android`, `flutter_webxdc_web`, ...) that implement
/// [WebxdcPlatform] — none exist yet.
library;

export 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

export 'src/webxdc_archive.dart';
export 'src/webxdc_controller.dart';
export 'src/webxdc_manifest.dart';
