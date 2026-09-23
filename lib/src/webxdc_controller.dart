import 'dart:async';

import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// Default value for `window.webxdc.sendUpdateInterval` when the host does
/// not override it, per doc/design.md §2.1.
const int kDefaultSendUpdateIntervalMs = 10000;

/// Default value for `window.webxdc.sendUpdateMaxSize` when the host does
/// not override it, per doc/design.md §2.1.
const int kDefaultSendUpdateMaxSizeBytes = 128000;

/// Thrown by [WebxdcController.sendUpdate] when the serialized `update`
/// object exceeds [WebxdcController.sendUpdateMaxSize].
class WebxdcUpdateTooLargeException implements Exception {
  WebxdcUpdateTooLargeException(this.sizeBytes, this.maxSizeBytes);

  final int sizeBytes;
  final int maxSizeBytes;

  @override
  String toString() =>
      'WebxdcUpdateTooLargeException: update is $sizeBytes bytes, '
      'exceeds sendUpdateMaxSize of $maxSizeBytes bytes';
}

/// App-facing controller that owns the per-app-instance update log described
/// in doc/design.md §4 ("Update/sync model: plugin vs. host boundary").
///
/// This is the platform-agnostic half of the plugin/host boundary: it is
/// what a [WebxdcPlatform] JS-bridge implementation (and the app-facing
/// [WebxdcSession] that wires one up) calls into when mini-app JS invokes
/// `sendUpdate`/`setUpdateListener`, and what the *hosting application*
/// calls into when a peer update arrives over its own transport (email,
/// chat protocol, etc.) via [deliverUpdate].
///
/// [WebxdcController] deliberately knows nothing about web views, JS
/// interop, or method channels — those live in the per-platform packages
/// (`flutter_webxdc_memory` today; `flutter_webxdc_android` / `_web` / ...
/// later). Prefer [WebxdcSession] for the fully wired path.
class WebxdcController {
  WebxdcController({
    required this.selfAddr,
    required this.selfName,
    this.sendUpdateInterval = kDefaultSendUpdateIntervalMs,
    this.sendUpdateMaxSize = kDefaultSendUpdateMaxSizeBytes,
  });

  /// Opaque, host-supplied pseudonymous address for the local user within
  /// this chat/app instance. Mirrors `window.webxdc.selfAddr`.
  final String selfAddr;

  /// Host-supplied display name for the local user. Mirrors
  /// `window.webxdc.selfName`.
  final String selfName;

  /// Mirrors `window.webxdc.sendUpdateInterval`.
  final int sendUpdateInterval;

  /// Mirrors `window.webxdc.sendUpdateMaxSize`.
  final int sendUpdateMaxSize;

  final List<WebxdcUpdate> _log = [];
  final StreamController<WebxdcUpdate> _updatesController =
      StreamController<WebxdcUpdate>.broadcast();

  /// The highest serial recorded so far, or `0` if no update has been
  /// recorded yet.
  int get maxSerial => _log.isEmpty ? 0 : _log.last.serial;

  /// Broadcast stream of every update recorded by this controller, in serial
  /// order, whether it originated from local mini-app JS ([sendUpdate]) or a
  /// remote peer ([deliverUpdate]). A host-side JS bridge implementation
  /// would forward these to `setUpdateListener`'s callback.
  Stream<WebxdcUpdate> get updates => _updatesController.stream;

  /// Records an update sent by the *local* mini-app JS via
  /// `window.webxdc.sendUpdate(update, descr)` and returns it with its
  /// assigned `serial`/`maxSerial`.
  ///
  /// Per doc/design.md §4, this only records the update and makes it
  /// available for replay/streaming; it is the **hosting application's**
  /// responsibility to actually transport it to other chat peers (e.g. by
  /// listening on [updates]).
  ///
  /// Throws [WebxdcUpdateTooLargeException] if the serialized payload
  /// exceeds [sendUpdateMaxSize].
  WebxdcUpdate sendUpdate(Map<String, Object?> update, {String? descr}) {
    final info = (update['info'] as String?) ?? descr;
    final withDescrFallback = <String, Object?>{...update};
    if (info != null) {
      withDescrFallback['info'] = info;
    }

    final sizeBytes = _estimateSizeBytes(withDescrFallback);
    if (sizeBytes > sendUpdateMaxSize) {
      throw WebxdcUpdateTooLargeException(sizeBytes, sendUpdateMaxSize);
    }

    final next = WebxdcUpdate.fromJson(
      withDescrFallback,
      serial: maxSerial + 1,
      maxSerial: maxSerial + 1,
    );
    return _record(next);
  }

  /// Records an update received from a **remote peer** via the hosting
  /// application's own transport (see doc/design.md §4). The host calls
  /// this after receiving peer data through whatever channel it uses; the
  /// controller assigns the next local serial and forwards it on [updates]
  /// exactly like a locally-sent update, so `setUpdateListener` replay
  /// behaves identically regardless of origin.
  WebxdcUpdate deliverUpdate(Map<String, Object?> update) {
    final next = WebxdcUpdate.fromJson(
      update,
      serial: maxSerial + 1,
      maxSerial: maxSerial + 1,
    );
    return _record(next);
  }

  WebxdcUpdate _record(WebxdcUpdate update) {
    final recorded = update.copyWith(maxSerial: update.serial);
    _log.add(recorded);
    _updatesController.add(recorded);
    return recorded;
  }

  /// Returns every recorded update with a serial greater than [serial],
  /// implementing the replay semantics of
  /// `window.webxdc.setUpdateListener(callback, serial)` (defaults to `0`,
  /// i.e. the full backlog).
  List<WebxdcUpdate> updatesSince(int serial) =>
      _log.where((u) => u.serial > serial).toList(growable: false);

  /// Releases the underlying stream controller. Must be called by the host
  /// when the app instance is disposed.
  Future<void> dispose() => _updatesController.close();

  static int _estimateSizeBytes(Map<String, Object?> update) {
    // A conservative, dependency-free approximation of the serialized JSON
    // size; a full JS-bridge implementation should measure the exact
    // `JSON.stringify` size on the JS side instead.
    return _estimateJsonSize(update);
  }

  static int _estimateJsonSize(Object? value) {
    if (value == null) return 4; // "null"
    if (value is String) return value.length + 2;
    if (value is num || value is bool) return value.toString().length;
    if (value is Map) {
      var size = 2; // {}
      for (final entry in value.entries) {
        size +=
            _estimateJsonSize(entry.key) +
            1 +
            _estimateJsonSize(entry.value) +
            1;
      }
      return size;
    }
    if (value is Iterable) {
      var size = 2; // []
      for (final item in value) {
        size += _estimateJsonSize(item) + 1;
      }
      return size;
    }
    return value.toString().length;
  }
}
