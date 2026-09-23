/// Platform-agnostic Dart API for implementing the
/// [webxdc specification](https://webxdc.org/docs/spec/index.html).
///
/// See `doc/design.md` for the full target architecture. This library
/// currently exposes the shared, platform-free contract described there:
/// `manifest.toml` parsing ([WebxdcManifest]), the `.xdc` zip container
/// reader ([WebxdcArchive]), the JS-bridge update model ([WebxdcUpdate]),
/// and the app-facing update log/replay controller ([WebxdcController]).
///
/// Platform hosting (Android/Desktop `flutter_inappwebview` web views, the
/// Web `<iframe>`/`postMessage` bridge) is not yet implemented; per
/// `doc/design.md` §2 it is planned as a follow-up federated-plugin split
/// (`flutter_webxdc_platform_interface` + per-platform packages).
library;

export 'src/webxdc_archive.dart';
export 'src/webxdc_controller.dart';
export 'src/webxdc_manifest.dart';
export 'src/webxdc_update.dart';
