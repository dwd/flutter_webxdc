/// A single status update, as sent by mini-app JS via
/// `window.webxdc.sendUpdate(update, descr)` or delivered back to it via
/// `setUpdateListener`.
///
/// See `doc/design.md` §2.1 for the full JS API contract this mirrors.
///
/// This type lives in `flutter_webxdc_platform_interface` (rather than the
/// app-facing `flutter_webxdc` package) because it is also the payload
/// shape [WebxdcPlatform] implementations exchange across the
/// method-channel/JS-message boundary with a per-platform package.
class WebxdcUpdate {
  const WebxdcUpdate({
    required this.payload,
    required this.serial,
    required this.maxSerial,
    this.info,
    this.document,
    this.summary,
    this.href,
    this.notify,
  });

  /// Arbitrary JSON-serializable application payload. Must not contain
  /// values that cannot round-trip through `jsonEncode`/`jsonDecode`
  /// (e.g. `NaN`, binary buffers).
  final Object? payload;

  /// Monotonically increasing serial assigned by the host/plugin when the
  /// update is recorded, used by `setUpdateListener(callback, serial)` to
  /// replay only updates newer than a given serial.
  final int serial;

  /// The highest serial known at the time this update was delivered; mini
  /// apps may use this to detect when they are caught up.
  final int maxSerial;

  /// Optional short status text (truncated to ~50 chars upstream, must not
  /// contain line breaks).
  final String? info;

  /// Optional short "document name" text (truncated to ~20 chars upstream,
  /// must not contain line breaks).
  final String? document;

  /// Optional one-line summary of the app's current state, typically shown
  /// in the chat list next to the app.
  final String? summary;

  /// Optional deep link/URL the host may use to focus a specific location
  /// in the app when the update is tapped.
  final String? href;

  /// Optional map from user address to notification text; the `"*"` key is
  /// a catch-all used when `selfAddr` is not present for the recipient.
  final Map<String, String>? notify;

  /// Builds the JSON-serializable map matching the shape the mini app's JS
  /// `setUpdateListener` callback receives (`serial`/`max_serial` merged in
  /// on top of the caller-supplied `update` object), see doc/design.md §2.1.
  Map<String, Object?> toJson() => {
    'payload': payload,
    'serial': serial,
    'max_serial': maxSerial,
    if (info != null) 'info': info,
    if (document != null) 'document': document,
    if (summary != null) 'summary': summary,
    if (href != null) 'href': href,
    if (notify != null) 'notify': notify,
  };

  /// Parses a [WebxdcUpdate] from a decoded JSON map, e.g. the `update`
  /// argument passed by mini-app JS to `sendUpdate(update, descr)`, combined
  /// with the `serial`/`maxSerial` assigned by the host when recording it.
  ///
  /// Throws a [FormatException] if `payload` is missing.
  factory WebxdcUpdate.fromJson(
    Map<String, Object?> json, {
    required int serial,
    required int maxSerial,
  }) {
    if (!json.containsKey('payload')) {
      throw const FormatException('update: `payload` is required');
    }
    final notifyRaw = json['notify'];
    Map<String, String>? notify;
    if (notifyRaw != null) {
      if (notifyRaw is! Map) {
        throw const FormatException(
          'update: `notify` must be a map of address to text if present',
        );
      }
      notify = notifyRaw.map(
        (key, value) => MapEntry(key as String, value as String),
      );
    }
    return WebxdcUpdate(
      payload: json['payload'],
      serial: serial,
      maxSerial: maxSerial,
      info: json['info'] as String?,
      document: json['document'] as String?,
      summary: json['summary'] as String?,
      href: json['href'] as String?,
      notify: notify,
    );
  }

  WebxdcUpdate copyWith({int? serial, int? maxSerial}) => WebxdcUpdate(
    payload: payload,
    serial: serial ?? this.serial,
    maxSerial: maxSerial ?? this.maxSerial,
    info: info,
    document: document,
    summary: summary,
    href: href,
    notify: notify,
  );

  @override
  String toString() =>
      'WebxdcUpdate(serial: $serial, maxSerial: $maxSerial, '
      'payload: $payload, info: $info, document: $document, '
      'summary: $summary, href: $href, notify: $notify)';
}
