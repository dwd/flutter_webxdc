/// The common platform interface for `flutter_webxdc`.
///
/// This library defines the stable Dart-side contract
/// ([WebxdcPlatform], [WebxdcUpdate]) that per-platform implementation
/// packages (`flutter_webxdc_android`, `flutter_webxdc_web`,
/// `flutter_webxdc_linux`, `flutter_webxdc_macos`, `flutter_webxdc_windows`)
/// must conform to.
///
/// See `doc/design.md` §2 ("Target federated package layout") in the
/// `flutter_webxdc` repository for the full target architecture. No
/// platform package implements [WebxdcPlatform] yet.
library;

export 'src/webxdc_imported_file.dart';
export 'src/webxdc_platform.dart';
export 'src/webxdc_update.dart';
