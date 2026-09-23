import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'webxdc_imported_file.dart';
import 'webxdc_update.dart';

/// The interface that every `flutter_webxdc` platform implementation must
/// implement.
///
/// This is the platform-implementation half of the `window.webxdc`
/// JS-bridge contract documented in `doc/design.md` §2.1: a per-platform
/// package (`flutter_webxdc_android`, `flutter_webxdc_web`,
/// `flutter_webxdc_linux`, `flutter_webxdc_macos`, `flutter_webxdc_windows`)
/// is responsible for hosting `.xdc` assets in a sandboxed web
/// view/`<iframe>`, injecting an equivalent `window.webxdc` shim, and
/// forwarding JS calls to these methods.
///
/// **Current status:** no platform package implements this yet (see
/// `doc/design.md` §2); this class currently only fixes the stable Dart
/// shape those future implementations must conform to, following the same
/// `PlatformInterface` + `instance` pattern used by other federated Flutter
/// plugins.
abstract class WebxdcPlatform extends PlatformInterface {
  /// Constructs a [WebxdcPlatform].
  ///
  /// Platform implementations should extend this class rather than
  /// implement it as an interface, so newly added methods default to
  /// throwing [UnimplementedError] instead of breaking existing
  /// implementations at compile time.
  WebxdcPlatform() : super(token: _token);

  static final Object _token = Object();

  static WebxdcPlatform? _instance;

  /// The platform implementation currently registered by a per-platform
  /// package, e.g. by calling `WebxdcPlatform.instance = FooWebxdc()` from
  /// its `registerWith()`.
  ///
  /// Throws a [StateError] if no platform package has registered an
  /// implementation yet — which is the case for every platform today (see
  /// `doc/design.md` §2). Platform-agnostic features of `flutter_webxdc`
  /// (`WebxdcManifest`, `WebxdcArchive`, `WebxdcController`) do not depend
  /// on this and work without any registered instance.
  static WebxdcPlatform get instance {
    final current = _instance;
    if (current == null) {
      throw StateError(
        'WebxdcPlatform.instance has not been set. No flutter_webxdc '
        'platform implementation package (e.g. flutter_webxdc_android, '
        'flutter_webxdc_web) is registered yet — see doc/design.md §2 for '
        'the target federated package layout.',
      );
    }
    return current;
  }

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WebxdcPlatform] when they
  /// register themselves.
  static set instance(WebxdcPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Test-only: clears the registered [instance], so tests can exercise the
  /// "no implementation registered" [StateError] and then install a fake.
  @visibleForTesting
  static void resetInstanceForTesting() => _instance = null;

  /// Hosts an already-extracted `.xdc` file tree (`path` -> file bytes) for
  /// [instanceId] in a sandboxed web view/`<iframe>`, and injects the
  /// `window.webxdc` shim with the given identity/capability values.
  ///
  /// `doc/design.md` §3 requires implementations to block outgoing network
  /// requests unless [requestInternetAccess] is `true`, and to give each
  /// [instanceId] isolated storage.
  Future<void> loadApp({
    required String instanceId,
    required Map<String, Uint8List> files,
    required String selfAddr,
    required String selfName,
    bool requestInternetAccess = false,
  }) {
    throw UnimplementedError('loadApp() has not been implemented.');
  }

  /// Forwards an update (already recorded by the app-facing
  /// `WebxdcController`) into the hosted web view/`<iframe>` for
  /// [instanceId], so its `setUpdateListener` callback observes it —
  /// regardless of whether the update originated locally or from a peer.
  Future<void> deliverUpdateToApp(String instanceId, WebxdcUpdate update) {
    throw UnimplementedError('deliverUpdateToApp() has not been implemented.');
  }

  /// Opens the host chat's compose/share UI pre-filled with [text] and/or
  /// the given file, per the `sendToChat(payload)` JS API (doc/design.md
  /// §2.1). At least one of [text] or [fileBytes] must be supplied.
  Future<void> sendToChat({
    required String instanceId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
  }) {
    throw UnimplementedError('sendToChat() has not been implemented.');
  }

  /// Triggers the platform's native file picker for [instanceId], per the
  /// `importFiles(filters)` JS API (doc/design.md §2.1). Returns the files
  /// selected by the user, or an empty list if the user cancelled.
  Future<List<WebxdcImportedFile>> importFiles({
    required String instanceId,
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) {
    throw UnimplementedError('importFiles() has not been implemented.');
  }

  /// Whether this platform implementation supports the experimental
  /// `joinRealtimeChannel()` API (doc/design.md §6 "Open questions /
  /// limitations"). Defaults to `false`; mini apps must feature-detect via
  /// `window.webxdc.joinRealtimeChannel !== undefined` rather than assuming
  /// support, and implementations are not required to override this.
  bool get supportsRealtimeChannel => false;

  /// Releases any resources (web view/`<iframe>`, listeners) associated
  /// with [instanceId].
  Future<void> disposeApp(String instanceId) {
    throw UnimplementedError('disposeApp() has not been implemented.');
  }
}
