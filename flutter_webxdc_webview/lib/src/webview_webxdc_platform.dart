import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

import 'webxdc_server.dart';

class _AppInstance {
  final WebxdcServer server;
  final bool requestInternetAccess;
  final String selfAddr;
  final String selfName;
  InAppWebViewController? controller;

  _AppInstance({
    required this.server,
    required this.requestInternetAccess,
    required this.selfAddr,
    required this.selfName,
  });
}

class WebviewWebxdcPlatform extends WebxdcPlatform {
  final Map<String, _AppInstance> _apps = {};

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
    if (app == null || app.controller == null) return;

    final updateJson = jsonEncode(update.toJson());
    final message = jsonEncode({
      'type': 'deliverUpdate',
      'update': jsonDecode(updateJson),
    });

    await app.controller!.evaluateJavascript(
      source: "window._webxdc_deliverMessage(${jsonEncode(message)});",
    );
  }

  @override
  Future<void> sendToChat({
    required String instanceId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
  }) async {
    // Currently, nothing to push back into the JS side for sendToChat unless
    // there's a response expected, but WebxdcPlatform's sendToChat just returns void.
  }

  @override
  Future<List<WebxdcImportedFile>> importFiles({
    required String instanceId,
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) async {
    return []; // Will implement file picker bridge if time permits
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
    final app = _apps[instanceId];
    if (app == null) {
      throw StateError('Instance $instanceId is not loaded.');
    }

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
        return new File([bytes], file.name, {type: file.mimeType || ''});
      }));
    }
  };
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

        controller.addJavaScriptHandler(
            handlerName: 'webxdc_sendUpdate',
            callback: (args) {
              final payload = args[0] as Map<String, dynamic>;
              _sendUpdateEvents.add(WebxdcJsSendUpdateEvent(
                instanceId: instanceId,
                update: payload['update'] as Map<String, Object?>,
                descr: payload['descr'] as String?,
              ));
            });

        controller.addJavaScriptHandler(
            handlerName: 'webxdc_setUpdateListener',
            callback: (args) {
              // JS sets up a listener, dart does not need to intervene as we push blindly.
            });

        controller.addJavaScriptHandler(
            handlerName: 'webxdc_sendToChat',
            callback: (args) {
              final payload = args[0] as Map<String, dynamic>;
              final chatPayload =
                  payload['payload'] as Map<String, dynamic>? ?? {};
              _sendToChatEvents.add(WebxdcJsSendToChatEvent(
                instanceId: instanceId,
                text: chatPayload['text'] as String?,
                fileName: chatPayload['name'] as String?,
                // ignoring base64 file data for now
              ));
            });

        controller.addJavaScriptHandler(
            handlerName: 'webxdc_importFiles',
            callback: (args) {
              // Handled programmatically via platform picker if needed
            });
      },
    );
  }
}
