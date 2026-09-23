import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'webxdc_imported_file.dart';
import 'webxdc_js_events.dart';
import 'webxdc_update.dart';

/// The interface that every `flutter_webxdc` platform implementation must
/// implement.
///
/// This is the platform-implementation half of the `window.webxdc`
/// JS-bridge contract documented in `doc/design.md` §2.1: a per-platform
/// package (`flutter_webxdc_android`, `flutter_webxdc_web`,
/// `flutter_webxdc_linux`, `flutter_webxdc_macos`, `flutter_webxdc_windows`,
/// and the in-memory `flutter_webxdc_memory` used for tests/default until
/// those land) is responsible for hosting `.xdc` assets in a sandboxed web
/// view/`<iframe>` (or an in-memory stand-in), injecting an equivalent
/// `window.webxdc` shim, and forwarding JS calls across this boundary.
///
/// Follows the same `PlatformInterface` + `instance` pattern used by other
/// federated Flutter plugins. Platform implementations should **extend**
/// this class rather than implement it, so newly added methods default to
/// throwing [UnimplementedError] instead of breaking existing
/// implementations at compile time.
abstract class WebxdcPlatform extends PlatformInterface {
  /// Constructs a [WebxdcPlatform].
  WebxdcPlatform() : super(token: _token);

  static final Object _token = Object();

  static WebxdcPlatform? _instance;

  /// The platform implementation currently registered by a per-platform
  /// package, e.g. by calling `WebxdcPlatform.instance = FooWebxdc()` from
  /// its `registerWith()`.
  ///
  /// Throws a [StateError] if no platform package has registered an
  /// implementation yet. The app-facing `flutter_webxdc` package will
  /// auto-register `MemoryWebxdcPlatform` via `FlutterWebxdc.ensureInitialized`
  /// when nothing else is registered, so host apps normally never observe
  /// this error.
  static WebxdcPlatform get instance {
    final current = _instance;
    if (current == null) {
      throw StateError(
        'WebxdcPlatform.instance has not been set. Call '
        'FlutterWebxdc.ensureInitialized() or register a platform package '
        '(e.g. flutter_webxdc_memory, flutter_webxdc_android) — see '
        'doc/design.md §2 for the target federated package layout.',
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
  ///
  /// Conforming implementations should also emit a
  /// [WebxdcJsSendToChatEvent] on [sendToChatEvents] so the host app can
  /// observe/handle the request (e.g. open its own compose UI).
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

  /// Stream of `sendUpdate` calls originating from mini-app JS.
  ///
  /// The host (via `WebxdcSession`) listens and records each event in the
  /// per-instance update log, then transports it to peers (doc/design.md
  /// §4). Defaults to an empty stream; platform implementations that host
  /// a real JS bridge must override and emit events.
  Stream<WebxdcJsSendUpdateEvent> get sendUpdateEvents =>
      const Stream<WebxdcJsSendUpdateEvent>.empty();

  /// Stream of `sendToChat` calls originating from mini-app JS.
  ///
  /// Defaults to an empty stream; platform implementations should emit
  /// here in addition to (or instead of relying solely on) the
  /// [sendToChat] method return, so the host can open its compose UI.
  Stream<WebxdcJsSendToChatEvent> get sendToChatEvents =>
      const Stream<WebxdcJsSendToChatEvent>.empty();
}
