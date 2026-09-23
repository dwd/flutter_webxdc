import 'dart:async';
import 'dart:convert';
// `dart:html` provides the browser compatibility layer used here until this
// first Web backend can move its event/file APIs to package:web.
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

import 'webxdc_web_protocol.dart';

/// Flutter Web [WebxdcPlatform] implementation.
///
/// Each loaded `.xdc` app is rendered as a sandboxed `srcdoc` iframe. The
/// iframe gets a messenger-owned `window.webxdc` shim and communicates with
/// this host through a JSON `postMessage` protocol that validates both the
/// frame source and an unpredictable per-instance token. The iframe is not
/// attached to the DOM automatically: after opening a session, call
/// [attachToElement] with the DOM container selected by the embedding Web app.
class WebWebxdcPlatform extends WebxdcPlatform {
  WebWebxdcPlatform() {
    html.window.onMessage.listen(_onMessage);
  }

  /// Registers a new browser host as [WebxdcPlatform.instance].
  static void registerWith() {
    WebxdcPlatform.instance = WebWebxdcPlatform();
  }

  final Map<String, _WebAppInstance> _apps = {};
  final StreamController<WebxdcJsSendUpdateEvent> _sendUpdateController =
      StreamController<WebxdcJsSendUpdateEvent>.broadcast();
  final StreamController<WebxdcJsSendToChatEvent> _sendToChatController =
      StreamController<WebxdcJsSendToChatEvent>.broadcast();

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
      throw StateError('WebWebxdcPlatform: "$instanceId" is already loaded');
    }
    final indexBytes = files['index.html'];
    if (indexBytes == null) {
      throw ArgumentError.value(
        files.keys.toList(),
        'files',
        'must contain the mandatory index.html entry point',
      );
    }

    final token = _newToken();
    final assetUrls = <String, String>{};
    for (final entry in files.entries) {
      if (entry.key == 'index.html') continue;
      assetUrls[entry.key] = _dataUrl(entry.key, entry.value);
    }
    final config = WebxdcWebBridgeConfig(
      instanceId: instanceId,
      token: token,
      selfAddr: selfAddr,
      selfName: selfName,
      requestInternetAccess: requestInternetAccess,
    );
    final iframe = html.IFrameElement()
      ..setAttribute('sandbox', 'allow-scripts')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..srcdoc = WebxdcWebDocumentBuilder.build(
        indexHtml: utf8.decode(indexBytes),
        assetUrls: assetUrls,
        config: config,
      );

    _apps[instanceId] = _WebAppInstance(
      iframe: iframe,
      token: token,
      requestInternetAccess: requestInternetAccess,
    );
  }

  /// Appends the sandboxed iframe for [instanceId] to [container].
  ///
  /// The container must be a browser [html.Element]. It is intentionally an
  /// [Object] in the public signature so importing this federated package on a
  /// non-Web target remains possible via its conditional stub.
  void attachToElement(String instanceId, Object container) {
    if (container is! html.Element) {
      throw ArgumentError.value(
        container,
        'container',
        'must be a browser Element on Flutter Web',
      );
    }
    final app = _requireApp(instanceId);
    container.append(app.iframe);
  }

  /// Returns the sandboxed iframe for [instanceId] as an opaque object.
  ///
  /// Callers on Flutter Web may cast it to [html.IFrameElement] when they need
  /// layout control. Prefer [attachToElement] for the usual embedding path.
  Object iframeFor(String instanceId) => _requireApp(instanceId).iframe;

  @override
  Future<void> deliverUpdateToApp(
    String instanceId,
    WebxdcUpdate update,
  ) async {
    final app = _requireApp(instanceId);
    app.deliveredUpdates.add(update);
    if (app.ready) {
      _post(
        app,
        WebxdcWebMessage(
          type: 'deliverUpdate',
          instanceId: instanceId,
          token: app.token,
          payload: <String, Object?>{'update': update.toJson()},
        ),
      );
    }
  }

  @override
  Future<void> sendToChat({
    required String instanceId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
  }) async {
    final app = _requireApp(instanceId);
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
    app.sendToChatLog.add(event);
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
    final input = html.FileUploadInputElement()
      ..multiple = multiple
      ..accept = <String>[
        ...?extensions?.map((extension) => '.$extension'),
        ...?mimeTypes,
      ].join(',')
      ..style.display = 'none';
    html.document.body!.append(input);
    input.click();
    await input.onChange.first;
    final selected = input.files;
    input.remove();
    if (selected == null) return const <WebxdcImportedFile>[];

    final imported = <WebxdcImportedFile>[];
    final count = multiple
        ? selected.length
        : (selected.length > 1 ? 1 : selected.length);
    for (var index = 0; index < count; index++) {
      final file = selected[index];
      final reader = html.FileReader()..readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      final buffer = reader.result;
      if (buffer is! ByteBuffer) continue;
      imported.add(
        WebxdcImportedFile(
          name: file.name,
          bytes: Uint8List.view(buffer),
          contentType: file.type.isEmpty ? null : file.type,
        ),
      );
    }
    return List<WebxdcImportedFile>.unmodifiable(imported);
  }

  @override
  Future<void> disposeApp(String instanceId) async {
    final app = _apps.remove(instanceId);
    app?.iframe.remove();
  }

  void _onMessage(html.MessageEvent event) {
    final message = WebxdcWebMessage.tryDecode(event.data);
    if (message == null) return;
    final app = _apps[message.instanceId];
    if (app == null ||
        app.token != message.token ||
        event.source != app.iframe.contentWindow) {
      return;
    }

    switch (message.type) {
      case 'ready':
        app.ready = true;
        for (final update in app.deliveredUpdates) {
          _post(
            app,
            WebxdcWebMessage(
              type: 'deliverUpdate',
              instanceId: message.instanceId,
              token: app.token,
              payload: <String, Object?>{'update': update.toJson()},
            ),
          );
        }
      case 'sendUpdate':
        final update = message.payload['update'];
        final descr = message.payload['descr'];
        if (update is Map && (descr == null || descr is String)) {
          _sendUpdateController.add(
            WebxdcJsSendUpdateEvent(
              instanceId: message.instanceId,
              update: Map<String, Object?>.from(update),
              descr: descr as String?,
            ),
          );
        }
      case 'sendToChat':
        _handleJsSendToChat(message, app);
      case 'importFiles':
        unawaited(_handleJsImportFiles(message, app));
    }
  }

  void _handleJsSendToChat(WebxdcWebMessage message, _WebAppInstance app) {
    final payload = message.payload['payload'];
    if (payload is! Map) return;
    final text = payload['text'];
    if (text is! String || text.isEmpty) {
      return;
    }
    final event = WebxdcJsSendToChatEvent(
      instanceId: message.instanceId,
      text: text,
    );
    app.sendToChatLog.add(event);
    _sendToChatController.add(event);
  }

  Future<void> _handleJsImportFiles(
    WebxdcWebMessage message,
    _WebAppInstance app,
  ) async {
    final requestId = message.payload['requestId'];
    final filters = message.payload['filters'];
    if (requestId is! String) return;
    final filterMap = filters is Map ? filters : const <Object?, Object?>{};
    final files = await importFiles(
      instanceId: message.instanceId,
      extensions: _stringList(filterMap['extensions']),
      mimeTypes: _stringList(filterMap['mimeTypes']),
      multiple: filterMap['multiple'] == true,
    );
    _post(
      app,
      WebxdcWebMessage(
        type: 'importFilesResult',
        instanceId: message.instanceId,
        token: app.token,
        payload: <String, Object?>{
          'requestId': requestId,
          'files': files
              .map(
                (file) => <String, Object?>{
                  'name': file.name,
                  'contentType': file.contentType,
                  'base64': base64Encode(file.bytes),
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }

  void _post(_WebAppInstance app, WebxdcWebMessage message) {
    app.iframe.contentWindow?.postMessage(message.encode(), '*');
  }

  _WebAppInstance _requireApp(String instanceId) {
    final app = _apps[instanceId];
    if (app == null) {
      throw StateError('WebWebxdcPlatform: no app loaded for "$instanceId"');
    }
    return app;
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List || value.any((item) => item is! String)) return null;
    return List<String>.from(value);
  }

  static String _newToken() {
    final random = html.window.crypto?.getRandomValues(Uint32List(4));
    if (random is Uint32List) {
      return random.map((value) => value.toRadixString(16)).join();
    }
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  }

  static String _dataUrl(String path, Uint8List bytes) {
    return 'data:${_contentTypeFor(path)};base64,${base64Encode(bytes)}';
  }

  static String _contentTypeFor(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'css' => 'text/css',
      'js' => 'text/javascript',
      'json' => 'application/json',
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'woff' => 'font/woff',
      'woff2' => 'font/woff2',
      _ => 'application/octet-stream',
    };
  }
}

/// Web plugin entry point used by Flutter's generated web registrant.
class FlutterWebxdcWebPlugin {
  static void registerWith(Registrar registrar) {
    WebWebxdcPlatform.registerWith();
  }
}

class _WebAppInstance {
  _WebAppInstance({
    required this.iframe,
    required this.token,
    required this.requestInternetAccess,
  });

  final html.IFrameElement iframe;
  final String token;
  final bool requestInternetAccess;
  final List<WebxdcUpdate> deliveredUpdates = <WebxdcUpdate>[];
  final List<WebxdcJsSendToChatEvent> sendToChatLog =
      <WebxdcJsSendToChatEvent>[];
  bool ready = false;
}
