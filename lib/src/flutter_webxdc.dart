import 'package:flutter_webxdc_memory/flutter_webxdc_memory.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// Top-level entry points for the app-facing `flutter_webxdc` package.
///
/// Handles platform-implementation registration so host apps (and
/// `WebxdcSession.open`) always have a [WebxdcPlatform.instance] to talk
/// to. Until a native/Web package registers itself, this falls back to
/// [MemoryWebxdcPlatform] — see doc/design.md §2.
class FlutterWebxdc {
  FlutterWebxdc._();

  /// Ensures a [WebxdcPlatform] implementation is registered.
  ///
  /// - If [platform] is supplied, it is installed as
  ///   [WebxdcPlatform.instance] (useful in tests).
  /// - Otherwise, if nothing is registered yet, installs a fresh
  ///   [MemoryWebxdcPlatform] via [MemoryWebxdcPlatform.registerWith].
  /// - If something is already registered, this is a no-op.
  ///
  /// Safe to call multiple times. Native/Web platform packages will call
  /// their own `registerWith()` from the Flutter plugin registrant before
  /// user code runs, so this only falls back to memory when no other
  /// backend is present.
  static void ensureInitialized({WebxdcPlatform? platform}) {
    if (platform != null) {
      WebxdcPlatform.instance = platform;
      return;
    }
    try {
      // Touch the getter: throws StateError when unset.
      WebxdcPlatform.instance;
    } on StateError {
      MemoryWebxdcPlatform.registerWith();
    }
  }
}
