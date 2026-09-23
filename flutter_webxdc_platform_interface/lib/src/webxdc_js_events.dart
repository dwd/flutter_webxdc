/// A `window.webxdc.sendUpdate(update, descr)` call originating from mini-app
/// JS and forwarded by a [WebxdcPlatform] implementation to the host.
///
/// The host (typically via the app-facing `WebxdcSession`) is responsible for
/// recording the update in its per-instance update log and transporting it to
/// peers — see doc/design.md §4.
class WebxdcJsSendUpdateEvent {
  const WebxdcJsSendUpdateEvent({
    required this.instanceId,
    required this.update,
    this.descr,
  });

  /// The hosted app instance that originated the call.
  final String instanceId;

  /// The `update` argument passed by mini-app JS to `sendUpdate`. Must
  /// contain at least a `payload` key (see [WebxdcUpdate.fromJson]).
  final Map<String, Object?> update;

  /// The optional legacy `descr` argument of `sendUpdate(update, descr)`,
  /// used as a fallback for `update.info` when `info` is absent.
  final String? descr;

  @override
  String toString() =>
      'WebxdcJsSendUpdateEvent(instanceId: $instanceId, update: $update, '
      'descr: $descr)';
}

/// A `window.webxdc.sendToChat(payload)` call originating from mini-app JS
/// and forwarded by a [WebxdcPlatform] implementation to the host.
///
/// At least one of [text] or [fileBytes] is guaranteed non-null by conforming
/// platform implementations (matching the JS API contract in doc/design.md
/// §2.1).
class WebxdcJsSendToChatEvent {
  const WebxdcJsSendToChatEvent({
    required this.instanceId,
    this.text,
    this.fileBytes,
    this.fileName,
    this.contentType,
  });

  /// The hosted app instance that originated the call.
  final String instanceId;

  /// Optional plain-text body to pre-fill the host chat compose UI with.
  final String? text;

  /// Optional file bytes to attach.
  final List<int>? fileBytes;

  /// Optional file name for [fileBytes].
  final String? fileName;

  /// Optional MIME type for [fileBytes].
  final String? contentType;

  @override
  String toString() =>
      'WebxdcJsSendToChatEvent(instanceId: $instanceId, text: $text, '
      'fileName: $fileName, contentType: $contentType, '
      'fileBytes: ${fileBytes?.length})';
}
