import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// In-memory [WebxdcPlatform] implementation used as the default backend
/// for plain `flutter test` and as the structural reference for future
/// native/Web platform packages (see doc/design.md §2).
///
/// Hosts `.xdc` file trees and the update bridge entirely in Dart process
/// memory — no WebView, iframe, or browser is required. Mini-app JS calls
/// are simulated via [simulateJsSendUpdate] (and the real [sendToChat] /
/// [importFiles] methods), which emit on [sendUpdateEvents] /
/// [sendToChatEvents] exactly like a JS-bridge implementation would.
class MemoryWebxdcPlatform extends WebxdcPlatform {
  /// Creates a new in-memory platform. Prefer [registerWith] to install it
  /// as [WebxdcPlatform.instance].
  MemoryWebxdcPlatform();

  /// Registers a fresh [MemoryWebxdcPlatform] as [WebxdcPlatform.instance].
  ///
  /// Mirrors the `registerWith()` entry point future
  /// `flutter_webxdc_android` / `_web` / ... packages will expose for the
  /// Flutter plugin registrant.
  static void registerWith() {
    WebxdcPlatform.instance = MemoryWebxdcPlatform();
  }

  final Map<String, _MemoryAppInstance> _apps = {};
  final StreamController<WebxdcJsSendUpdateEvent> _sendUpdateController =
      StreamController<WebxdcJsSendUpdateEvent>.broadcast();
  final StreamController<WebxdcJsSendToChatEvent> _sendToChatController =
      StreamController<WebxdcJsSendToChatEvent>.broadcast();

  /// Queued files returned by the next [importFiles] call for a given
  /// instance, set via [queueImportedFiles]. Cleared after each call.
  final Map<String, List<WebxdcImportedFile>> _importQueues = {};

  @override
  Stream<WebxdcJsSendUpdateEvent> get sendUpdateEvents =>
      _sendUpdateController.stream;

  @override
  Stream<WebxdcJsSendToChatEvent> get sendToChatEvents =>
      _sendToChatController.stream;

  @override
  Future<void> loadApp({
    required String instanceId,
    required Map<String, Uint8List> files,
    required String selfAddr,
    required String selfName,
    bool requestInternetAccess = false,
  }) async {
    if (_apps.containsKey(instanceId)) {
      throw StateError(
        'MemoryWebxdcPlatform: app instance "$instanceId" is already loaded',
      );
    }
    if (!files.containsKey('index.html')) {
      throw ArgumentError.value(
        files.keys.toList(),
        'files',
        'must contain the mandatory index.html entry point',
      );
    }
    _apps[instanceId] = _MemoryAppInstance(
      files: Map<String, Uint8List>.unmodifiable(
        Map<String, Uint8List>.from(files),
      ),
      selfAddr: selfAddr,
      selfName: selfName,
      requestInternetAccess: requestInternetAccess,
    );
  }

  @override
  Future<void> deliverUpdateToApp(
    String instanceId,
    WebxdcUpdate update,
  ) async {
    _requireApp(instanceId).deliveredUpdates.add(update);
  }

  @override
  Future<void> sendToChat({
    required String instanceId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
  }) async {
    _requireApp(instanceId);
    if (text == null && fileBytes == null) {
      throw ArgumentError(
        'sendToChat: at least one of text or fileBytes must be supplied',
      );
    }
    final event = WebxdcJsSendToChatEvent(
      instanceId: instanceId,
      text: text,
      fileBytes: fileBytes,
      fileName: fileName,
      contentType: contentType,
    );
    _requireApp(instanceId).sendToChatLog.add(event);
    _sendToChatController.add(event);
  }

  @override
  Future<List<WebxdcImportedFile>> importFiles({
    required String instanceId,
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) async {
    _requireApp(instanceId);
    final queued = _importQueues.remove(instanceId);
    if (queued == null) return const <WebxdcImportedFile>[];
    if (!multiple && queued.length > 1) {
      return queued.sublist(0, 1);
    }
    return List<WebxdcImportedFile>.unmodifiable(queued);
  }

  @override
  Future<void> disposeApp(String instanceId) async {
    _apps.remove(instanceId);
    _importQueues.remove(instanceId);
  }

  /// Simulates mini-app JS calling `window.webxdc.sendUpdate(update, descr)`.
  ///
  /// Emits a [WebxdcJsSendUpdateEvent] on [sendUpdateEvents] so a listening
  /// `WebxdcSession` records it via `WebxdcController.sendUpdate` and
  /// transports it to peers — the same path a real JS bridge would take.
  ///
  /// Throws [StateError] if [instanceId] is not currently loaded.
  void simulateJsSendUpdate(
    String instanceId,
    Map<String, Object?> update, {
    String? descr,
  }) {
    _requireApp(instanceId);
    _sendUpdateController.add(
      WebxdcJsSendUpdateEvent(
        instanceId: instanceId,
        update: update,
        descr: descr,
      ),
    );
  }

  /// Pre-seeds the files that the next [importFiles] call for [instanceId]
  /// will return (simulating a user picking files). Cleared after one call.
  void queueImportedFiles(String instanceId, List<WebxdcImportedFile> files) {
    _requireApp(instanceId);
    _importQueues[instanceId] = List<WebxdcImportedFile>.from(files);
  }

  /// Whether [instanceId] is currently loaded via [loadApp].
  bool isLoaded(String instanceId) => _apps.containsKey(instanceId);

  /// Updates delivered into the hosted app for [instanceId] via
  /// [deliverUpdateToApp] (i.e. what `setUpdateListener` would have seen),
  /// in delivery order.
  List<WebxdcUpdate> deliveredUpdates(String instanceId) =>
      List<WebxdcUpdate>.unmodifiable(_requireApp(instanceId).deliveredUpdates);

  /// `sendToChat` requests recorded for [instanceId], in call order.
  List<WebxdcJsSendToChatEvent> sendToChatLog(String instanceId) =>
      List<WebxdcJsSendToChatEvent>.unmodifiable(
        _requireApp(instanceId).sendToChatLog,
      );

  /// Read-only view of the file tree loaded for [instanceId].
  Map<String, Uint8List> filesOf(String instanceId) =>
      _requireApp(instanceId).files;

  /// Identity injected at [loadApp] time for [instanceId].
  String selfAddrOf(String instanceId) => _requireApp(instanceId).selfAddr;

  /// Display name injected at [loadApp] time for [instanceId].
  String selfNameOf(String instanceId) => _requireApp(instanceId).selfName;

  /// Whether [instanceId] was loaded with `requestInternetAccess: true`.
  bool requestInternetAccessOf(String instanceId) =>
      _requireApp(instanceId).requestInternetAccess;

  /// Test helper: drops every loaded app and queued import without closing
  /// the event streams (so the same instance can be reused across tests).
  @visibleForTesting
  void resetAppsForTesting() {
    _apps.clear();
    _importQueues.clear();
  }

  _MemoryAppInstance _requireApp(String instanceId) {
    final app = _apps[instanceId];
    if (app == null) {
      throw StateError(
        'MemoryWebxdcPlatform: no app loaded for instance "$instanceId"',
      );
    }
    return app;
  }
}

class _MemoryAppInstance {
  _MemoryAppInstance({
    required this.files,
    required this.selfAddr,
    required this.selfName,
    required this.requestInternetAccess,
  });

  final Map<String, Uint8List> files;
  final String selfAddr;
  final String selfName;
  final bool requestInternetAccess;
  final List<WebxdcUpdate> deliveredUpdates = [];
  final List<WebxdcJsSendToChatEvent> sendToChatLog = [];
}
