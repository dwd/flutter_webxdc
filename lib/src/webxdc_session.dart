import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

import 'flutter_webxdc.dart';
import 'webxdc_archive.dart';
import 'webxdc_controller.dart';

/// A running per-chat/app instance of a WebXDC mini app.
///
/// This is the app-facing glue between:
/// - [WebxdcArchive] / [WebxdcController] (platform-agnostic shared core), and
/// - [WebxdcPlatform] (the federated platform implementation that actually
///   hosts the `.xdc` assets and the JS bridge).
///
/// Lifecycle (doc/design.md §4):
/// 1. [open] parses the `.xdc` zip, creates a [WebxdcController], and calls
///    [WebxdcPlatform.loadApp] on the registered platform.
/// 2. Every update recorded on [controller] (local [sendUpdate] or peer
///    [deliverPeerUpdate]) is forwarded into the hosted app via
///    [WebxdcPlatform.deliverUpdateToApp].
/// 3. `sendUpdate` calls originating from mini-app JS (emitted on
///    [WebxdcPlatform.sendUpdateEvents]) are recorded via
///    [WebxdcController.sendUpdate] and thus take the same path.
/// 4. [dispose] tears down subscriptions, the controller, and the platform
///    host for this [instanceId].
class WebxdcSession {
  WebxdcSession._({
    required this.instanceId,
    required this.archive,
    required this.controller,
    required this._platform,
    required this._updatesSubscription,
    required this._jsSendUpdateSubscription,
  });

  /// Opaque id for this chat/app instance, shared with [WebxdcPlatform].
  final String instanceId;

  /// The parsed `.xdc` archive this session was opened from.
  final WebxdcArchive archive;

  /// The per-instance update log/replay controller (doc/design.md §4).
  final WebxdcController controller;

  final WebxdcPlatform _platform;
  final StreamSubscription<WebxdcUpdate> _updatesSubscription;
  final StreamSubscription<WebxdcJsSendUpdateEvent> _jsSendUpdateSubscription;
  bool _disposed = false;

  /// The [WebxdcPlatform] this session is bound to.
  WebxdcPlatform get platform => _platform;

  /// Broadcast stream of every update recorded by [controller], whether it
  /// originated from local mini-app JS, a host-side [sendUpdate], or a peer
  /// via [deliverPeerUpdate]. Host apps listen here to transport updates to
  /// other chat peers (doc/design.md §4).
  Stream<WebxdcUpdate> get updates => controller.updates;

  /// Opens a new session from raw `.xdc` zip [xdcBytes].
  ///
  /// Calls [FlutterWebxdc.ensureInitialized] (so a platform is always
  /// registered), parses the archive, creates a [WebxdcController] with the
  /// given identity, and asks the platform to [WebxdcPlatform.loadApp].
  ///
  /// [platform] may be supplied to bind this session to a specific
  /// implementation (e.g. a test double); otherwise [WebxdcPlatform.instance]
  /// is used.
  static Future<WebxdcSession> open({
    required Uint8List xdcBytes,
    required String instanceId,
    required String selfAddr,
    required String selfName,
    WebxdcPlatform? platform,
    int sendUpdateInterval = kDefaultSendUpdateIntervalMs,
    int sendUpdateMaxSize = kDefaultSendUpdateMaxSizeBytes,
  }) async {
    FlutterWebxdc.ensureInitialized(platform: platform);
    final resolvedPlatform = platform ?? WebxdcPlatform.instance;

    final archive = WebxdcArchive.fromBytes(xdcBytes);
    final controller = WebxdcController(
      selfAddr: selfAddr,
      selfName: selfName,
      sendUpdateInterval: sendUpdateInterval,
      sendUpdateMaxSize: sendUpdateMaxSize,
    );

    await resolvedPlatform.loadApp(
      instanceId: instanceId,
      files: archive.files,
      selfAddr: selfAddr,
      selfName: selfName,
      requestInternetAccess: archive.manifest?.requestInternetAccess ?? false,
    );

    // Forward every recorded update into the hosted app (setUpdateListener).
    final updatesSubscription = controller.updates.listen((update) {
      // deliverUpdateToApp is async but fire-and-forget here: the memory
      // backend completes synchronously, and native backends will queue
      // into the web view. Errors surface via the subscription's
      // onError if a caller attaches one.
      unawaited(resolvedPlatform.deliverUpdateToApp(instanceId, update));
    });

    // Record sendUpdate calls originating from mini-app JS.
    final jsSendUpdateSubscription = resolvedPlatform.sendUpdateEvents
        .where((event) => event.instanceId == instanceId)
        .listen((event) {
          controller.sendUpdate(event.update, descr: event.descr);
        });

    return WebxdcSession._(
      instanceId: instanceId,
      archive: archive,
      controller: controller,
      platform: resolvedPlatform,
      updatesSubscription: updatesSubscription,
      jsSendUpdateSubscription: jsSendUpdateSubscription,
    );
  }

  /// Records an update as if the *local* mini-app JS had called
  /// `window.webxdc.sendUpdate(update, descr)`.
  ///
  /// The update is stored on [controller], emitted on [updates] (so the
  /// host can transport it to peers), and forwarded into the hosted app
  /// via [WebxdcPlatform.deliverUpdateToApp].
  WebxdcUpdate sendUpdate(Map<String, Object?> update, {String? descr}) {
    _ensureOpen();
    return controller.sendUpdate(update, descr: descr);
  }

  /// Records an update received from a **remote peer** via the hosting
  /// application's own transport (doc/design.md §4).
  WebxdcUpdate deliverPeerUpdate(Map<String, Object?> update) {
    _ensureOpen();
    return controller.deliverUpdate(update);
  }

  /// Convenience: forwards to [WebxdcPlatform.sendToChat] for this instance.
  Future<void> sendToChat({
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
  }) {
    _ensureOpen();
    return _platform.sendToChat(
      instanceId: instanceId,
      text: text,
      fileBytes: fileBytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  /// Convenience: forwards to [WebxdcPlatform.importFiles] for this instance.
  Future<List<WebxdcImportedFile>> importFiles({
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) {
    _ensureOpen();
    return _platform.importFiles(
      instanceId: instanceId,
      extensions: extensions,
      mimeTypes: mimeTypes,
      multiple: multiple,
    );
  }

  /// Tears down subscriptions, the [controller], and the platform host for
  /// this [instanceId]. Safe to call only once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _updatesSubscription.cancel();
    await _jsSendUpdateSubscription.cancel();
    await controller.dispose();
    await _platform.disposeApp(instanceId);
  }

  void _ensureOpen() {
    if (_disposed) {
      throw StateError('WebxdcSession($instanceId) has been disposed');
    }
  }
}
