/// Platform-agnostic Dart API for implementing the
/// [webxdc specification](https://webxdc.org/docs/spec/index.html).
///
/// See `doc/design.md` for the full target architecture. This library
/// exposes the app-facing half of the federated package layout described
/// there (§2):
///
/// - `manifest.toml` parsing ([WebxdcManifest])
/// - `.xdc` zip container reader ([WebxdcArchive])
/// - per-instance update log/replay ([WebxdcController])
/// - the session glue that wires those to a [WebxdcPlatform]
///   implementation ([WebxdcSession], [FlutterWebxdc])
///
/// It also re-exports the stable platform contract from
/// `flutter_webxdc_platform_interface` and the default in-memory platform
/// (`MemoryWebxdcPlatform` from `flutter_webxdc_memory`) so most consumers
/// only need to depend on this package.
///
/// Native WebView / Web iframe hosting is not yet implemented; those live
/// in future per-platform packages (`flutter_webxdc_android`,
/// `flutter_webxdc_web`, ...) that will replace [MemoryWebxdcPlatform] via
/// the same [WebxdcPlatform.instance] registration path.
library;

export 'package:flutter_webxdc_memory/flutter_webxdc_memory.dart'
    show MemoryWebxdcPlatform;
export 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

export 'src/flutter_webxdc.dart';
export 'src/webxdc_archive.dart';
export 'src/webxdc_controller.dart';
export 'src/webxdc_manifest.dart';
export 'src/webxdc_session.dart';
