import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_forge/flutter_inappwebview_forge.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

import 'webxdc_server.dart';

class _AppInstance {
  final WebxdcServer server;
  final bool requestInternetAccess;
  final String selfAddr;
  final String selfName;
  final List<WebxdcUpdate> pendingUpdates = <WebxdcUpdate>[];
  final List<WebxdcJsSendToChatEvent> sendToChatLog =
      <WebxdcJsSendToChatEvent>[];
  InAppWebViewController? controller;

  _AppInstance({
    required this.server,
    required this.requestInternetAccess,
    required this.selfAddr,
    required this.selfName,
  });
}

typedef WebxdcFilePicker = Future<List<WebxdcImportedFile>> Function({
  List<String>? extensions,
  List<String>? mimeTypes,
  bool multiple,
});

class WebviewWebxdcPlatform extends WebxdcPlatform {
  WebviewWebxdcPlatform({WebxdcFilePicker? filePicker})
      : _filePicker = filePicker ?? _pickFilesWithSelector;

  final Map<String, _AppInstance> _apps = {};
  final WebxdcFilePicker _filePicker;

  final StreamController<WebxdcJsSendUpdateEvent> _sendUpdateEvents =
      StreamController.broadcast();
  final StreamController<WebxdcJsSendToChatEvent> _sendToChatEvents =
      StreamController.broadcast();

  @override
  Stream<WebxdcJsSendUpdateEvent> get sendUpdateEvents =>
      _sendUpdateEvents.stream;

  @override
  Stream<WebxdcJsSendToChatEvent> get sendToChatEvents =>
      _sendToChatEvents.stream;

  @override
  Future<void> loadApp({
    required String instanceId,
    required Map<String, Uint8List> files,
    required String selfAddr,
    required String selfName,
    bool requestInternetAccess = false,
  }) async {
    if (_apps.containsKey(instanceId)) {
      throw StateError('Instance $instanceId is already loaded.');
    }

    final server =
        WebxdcServer(files, requestInternetAccess: requestInternetAccess);
    await server.start();

    _apps[instanceId] = _AppInstance(
      server: server,
      requestInternetAccess: requestInternetAccess,
      selfAddr: selfAddr,
      selfName: selfName,
    );
  }

  @override
  Future<void> deliverUpdateToApp(
      String instanceId, WebxdcUpdate update) async {
    final app = _apps[instanceId];
    if (app == null) return;
    final controller = app.controller;
    if (controller == null) {
      app.pendingUpdates.add(update);
      return;
    }
    await _deliverUpdate(controller, update);
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
    _sendToChatEvents.add(event);
  }

  @override
  Future<List<WebxdcImportedFile>> importFiles({
    required String instanceId,
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) async {
    _requireApp(instanceId);
    return _filePicker(
      extensions: extensions,
      mimeTypes: mimeTypes,
      multiple: multiple,
    );
  }

  @override
  Widget buildHostWidget(String instanceId, {Key? key}) {
    return WebxdcSizeObserver(
      key: key,
      builder: () => buildWebView(instanceId),
      onSizeChanged: (_) => _notifyResize(instanceId),
    );
  }

  /// Tells the hosted app that its on-screen size changed, by dispatching
  /// a DOM `resize` event inside the WebView.
  ///
  /// Many mini-apps size themselves (canvas dimensions, flex layouts, game
  /// viewports) once at load time from `window.innerWidth`/`innerHeight`
  /// and never re-measure afterwards; without this, resizing the embedding
  /// card (e.g. maximizing/restoring it) never reaches the app, so it keeps
  /// rendering for its original size. See doc/design.md §2/§6.
  void _notifyResize(String instanceId) {
    final controller = _apps[instanceId]?.controller;
    if (controller == null) return;
    unawaited(
      controller.evaluateJavascript(
        source: 'window.dispatchEvent(new Event("resize"));',
      ),
    );
  }

  @override
  Future<void> disposeApp(String instanceId) async {
    final app = _apps.remove(instanceId);
    if (app != null) {
      await app.server.stop();
    }
  }

  /// Builds the [InAppWebView] widget for the given [instanceId].
  ///
  /// This must be called after [loadApp] resolves successfully.
  Widget buildWebView(String instanceId) {
    final app = _requireApp(instanceId);

    final port = app.server.port;
    final configJson = jsonEncode(<String, Object?>{
      'instanceId': instanceId,
      'selfAddr': app.selfAddr,
      'selfName': app.selfName,
    }).replaceAll('</', r'<\/');

    final userScript = UserScript(
      source: '''
(() => {
  'use strict';
  const config = $configJson;
  const backlog = [];
  const importRequests = new Map();
  let listener = null;
  let nextRequestId = 0;

  const emit = (type, payload = {}) => {
    window.flutter_inappwebview.callHandler('webxdc_' + type, payload);
  };
  
  const replay = (serial) => {
    if (!listener) return;
    backlog.filter((update) => update.serial > serial).forEach((update) => listener(update));
  };

  window.webxdc = Object.freeze({
    selfAddr: config.selfAddr,
    selfName: config.selfName,
    sendUpdate(update, descr) {
      emit('sendUpdate', {update, descr});
      return Promise.resolve();
    },
    setUpdateListener(callback, serial = 0) {
      listener = callback;
      replay(serial);
      emit('setUpdateListener', {serial});
      return Promise.resolve();
    },
    sendToChat(payload) {
      emit('sendToChat', {payload});
      return Promise.resolve();
    },
    importFiles(filters = {}) {
      const requestId = String(++nextRequestId);
      emit('importFiles', {requestId, filters});
      return new Promise((resolve) => importRequests.set(requestId, resolve));
    },
  });

  window._webxdc_deliverMessage = (messageJson) => {
    let message;
    try { message = JSON.parse(messageJson); } catch (_) { return; }
    if (message.type === 'deliverUpdate') {
      backlog.push(message.update);
      if (listener) listener(message.update);
      return;
    }
    if (message.type === 'importFilesResult') {
      const resolve = importRequests.get(message.requestId);
      if (!resolve) return;
      importRequests.delete(message.requestId);
      resolve((message.files || []).map((file) => {
        const binary = atob(file.base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        return new File([bytes], file.name, {type: file.contentType || ''});
      }));
    }
  };

  // Re-dispatch a window-level 'resize' event whenever the document's own
  // layout box changes size, for apps that observe their own elements with
  // ResizeObserver instead of listening for window 'resize' directly. The
  // host (Dart side) also dispatches 'resize' directly on card/viewport
  // size changes; this is a cheap, additional signal for that other case.
  if (typeof ResizeObserver !== 'undefined') {
    let lastWidth = 0;
    let lastHeight = 0;
    new ResizeObserver((entries) => {
      const entry = entries[0];
      if (!entry) return;
      const {width, height} = entry.contentRect;
      if (width === lastWidth && height === lastHeight) return;
      lastWidth = width;
      lastHeight = height;
      window.dispatchEvent(new Event('resize'));
    }).observe(document.documentElement);
  }
})();
''',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    return InAppWebView(
      initialUrlRequest:
          URLRequest(url: WebUri('http://127.0.0.1:$port/index.html')),
      initialUserScripts: UnmodifiableListView<UserScript>([userScript]),
      onWebViewCreated: (controller) {
        app.controller = controller;
        for (final update in app.pendingUpdates) {
          unawaited(_deliverUpdate(controller, update));
        }
        app.pendingUpdates.clear();

        controller.addJavaScriptHandler(
          handlerName: 'webxdc_sendUpdate',
          callback: (args) {
            final payload = _firstMap(args);
            final update = payload?['update'];
            final descr = payload?['descr'];
            if (update is! Map || (descr != null && descr is! String)) {
              return;
            }
            _sendUpdateEvents.add(
              WebxdcJsSendUpdateEvent(
                instanceId: instanceId,
                update: Map<String, Object?>.from(update),
                descr: descr as String?,
              ),
            );
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'webxdc_setUpdateListener',
          callback: (args) {
            // JS sets up a listener, Dart does not need to intervene because we
            // always push/backlog updates from the host side.
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'webxdc_sendToChat',
          callback: (args) {
            final payload = _firstMap(args);
            final event = _parseSendToChatEvent(
              instanceId: instanceId,
              payload: payload,
            );
            if (event == null) return;
            app.sendToChatLog.add(event);
            _sendToChatEvents.add(event);
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'webxdc_importFiles',
          callback: (args) async {
            final payload = _firstMap(args);
            final requestId = payload?['requestId'];
            final filters = payload?['filters'];
            if (requestId is! String) return;
            final filterMap = filters is Map
                ? Map<String, Object?>.from(filters)
                : const <String, Object?>{};
            final files = await importFiles(
              instanceId: instanceId,
              extensions: _stringList(filterMap['extensions']),
              mimeTypes: _stringList(filterMap['mimeTypes']),
              multiple: filterMap['multiple'] == true,
            );
            await _deliverImportFilesResult(controller, requestId, files);
          },
        );
      },
    );
  }

  @visibleForTesting
  int pendingUpdateCount(String instanceId) =>
      _requireApp(instanceId).pendingUpdates.length;

  @visibleForTesting
  List<WebxdcJsSendToChatEvent> sendToChatLog(String instanceId) =>
      List<WebxdcJsSendToChatEvent>.unmodifiable(
        _requireApp(instanceId).sendToChatLog,
      );

  _AppInstance _requireApp(String instanceId) {
    final app = _apps[instanceId];
    if (app == null) {
      throw StateError('Instance $instanceId is not loaded.');
    }
    return app;
  }

  Future<void> _deliverUpdate(
    InAppWebViewController controller,
    WebxdcUpdate update,
  ) {
    final updateJson = jsonEncode(update.toJson());
    final message = jsonEncode(<String, Object?>{
      'type': 'deliverUpdate',
      'update': jsonDecode(updateJson),
    });
    return controller.evaluateJavascript(
      source: 'window._webxdc_deliverMessage(${jsonEncode(message)});',
    );
  }

  Future<void> _deliverImportFilesResult(
    InAppWebViewController controller,
    String requestId,
    List<WebxdcImportedFile> files,
  ) {
    final message = jsonEncode(<String, Object?>{
      'type': 'importFilesResult',
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
    });
    return controller.evaluateJavascript(
      source: 'window._webxdc_deliverMessage(${jsonEncode(message)});',
    );
  }

  static Map<String, Object?>? _firstMap(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) return null;
    return Map<String, Object?>.from(args.first as Map);
  }

  static WebxdcJsSendToChatEvent? _parseSendToChatEvent({
    required String instanceId,
    required Map<String, Object?>? payload,
  }) {
    final chatPayload = payload?['payload'];
    if (chatPayload is! Map) return null;
    final map = Map<String, Object?>.from(chatPayload);
    final text = map['text'];
    final file = map['file'];
    Uint8List? fileBytes;
    String? fileName;
    String? contentType;
    if (file is Map) {
      final fileMap = Map<String, Object?>.from(file);
      final base64Data = fileMap['base64'];
      final name = fileMap['name'];
      final type = fileMap['contentType'];
      if (base64Data is String) {
        fileBytes = Uint8List.fromList(base64Decode(base64Data));
      }
      if (name is String && name.isNotEmpty) {
        fileName = name;
      }
      if (type is String && type.isNotEmpty) {
        contentType = type;
      }
    }
    if (text is! String && fileBytes == null) {
      return null;
    }
    return WebxdcJsSendToChatEvent(
      instanceId: instanceId,
      text: text is String ? text : null,
      fileBytes: fileBytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List || value.any((item) => item is! String)) return null;
    return List<String>.from(value);
  }

  static Future<List<WebxdcImportedFile>> _pickFilesWithSelector({
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) async {
    final normalizedExtensions = extensions
        ?.where((extension) => extension.trim().isNotEmpty)
        .map((extension) => extension.replaceFirst(RegExp(r'^\.'), ''))
        .toList(growable: false);
    final normalizedMimeTypes = mimeTypes
        ?.where((mimeType) => mimeType.trim().isNotEmpty)
        .toList(growable: false);

    final acceptedTypeGroups =
        (normalizedExtensions != null && normalizedExtensions.isNotEmpty) ||
                (normalizedMimeTypes != null && normalizedMimeTypes.isNotEmpty)
            ? <XTypeGroup>[
                XTypeGroup(
                  label: 'webxdc import',
                  extensions: normalizedExtensions,
                  mimeTypes: normalizedMimeTypes,
                ),
              ]
            : const <XTypeGroup>[];

    final selected = multiple
        ? await openFiles(acceptedTypeGroups: acceptedTypeGroups)
        : <XFile>[
            if (await openFile(acceptedTypeGroups: acceptedTypeGroups)
                case final XFile file)
              file,
          ];

    final imported = <WebxdcImportedFile>[];
    for (final file in selected) {
      imported.add(
        WebxdcImportedFile(
          name: file.name,
          bytes: await file.readAsBytes(),
          contentType: file.mimeType,
        ),
      );
    }
    return List<WebxdcImportedFile>.unmodifiable(imported);
  }
}
