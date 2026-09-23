import 'dart:convert';

/// Versioned wire format shared by the parent Flutter page and the sandboxed
/// WebXDC iframe.
///
/// Messages are JSON strings rather than structured-cloned Dart/JS objects so
/// both endpoints can validate an exact, platform-independent shape before
/// handling a mini-app request. [token] is per loaded instance; it complements
/// the browser's `event.source` check because sandboxed `srcdoc` frames have
/// an opaque (`null`) origin.
class WebxdcWebMessage {
  const WebxdcWebMessage({
    required this.type,
    required this.instanceId,
    required this.token,
    this.payload = const <String, Object?>{},
  });

  static const channel = 'flutter_webxdc.web/1';

  final String type;
  final String instanceId;
  final String token;
  final Map<String, Object?> payload;

  String encode() => jsonEncode(<String, Object?>{
    'channel': channel,
    'type': type,
    'instanceId': instanceId,
    'token': token,
    ...payload,
  });

  /// Decodes a bridge message, returning `null` for unrelated or malformed
  /// browser messages rather than exposing them to the host bridge.
  static WebxdcWebMessage? tryDecode(Object? value) {
    if (value is! String) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final map = Map<String, Object?>.from(decoded);
      if (map['channel'] != channel ||
          map['type'] is! String ||
          map['instanceId'] is! String ||
          map['token'] is! String) {
        return null;
      }
      final payload = Map<String, Object?>.from(map)
        ..remove('channel')
        ..remove('type')
        ..remove('instanceId')
        ..remove('token');
      return WebxdcWebMessage(
        type: map['type']! as String,
        instanceId: map['instanceId']! as String,
        token: map['token']! as String,
        payload: payload,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Inputs required to generate a sandboxed iframe document and its injected
/// `window.webxdc` shim.
class WebxdcWebBridgeConfig {
  const WebxdcWebBridgeConfig({
    required this.instanceId,
    required this.token,
    required this.selfAddr,
    required this.selfName,
    required this.requestInternetAccess,
  });

  final String instanceId;
  final String token;
  final String selfAddr;
  final String selfName;
  final bool requestInternetAccess;
}

/// Builds a self-contained iframe `srcdoc` from an app's `index.html`.
///
/// Archive asset URLs must already be safe `data:` URLs. The builder rewrites
/// quoted relative `src` and `href` attributes that name an archive asset. It
/// deliberately leaves all other URLs untouched; the injected CSP blocks them
/// unless the app's manifest requested internet access.
class WebxdcWebDocumentBuilder {
  const WebxdcWebDocumentBuilder._();

  static String build({
    required String indexHtml,
    required Map<String, String> assetUrls,
    required WebxdcWebBridgeConfig config,
  }) {
    final rewritten = indexHtml.replaceAllMapped(
      RegExp(r'''\b(src|href)\s*=\s*(["'])([^"']+)\2''', caseSensitive: false),
      (match) {
        final original = match.group(3)!;
        final normalized = original.startsWith('./')
            ? original.substring(2)
            : original;
        final replacement = assetUrls[normalized];
        if (replacement == null) return match.group(0)!;
        return '${match.group(1)}=${match.group(2)}$replacement${match.group(2)}';
      },
    );

    final csp = _contentSecurityPolicy(config.requestInternetAccess);
    final head =
        '<meta http-equiv="Content-Security-Policy" content="$csp">'
        '<script>${_shim(config)}</script>';
    final headStart = RegExp(r'<head\b[^>]*>', caseSensitive: false);
    if (headStart.hasMatch(rewritten)) {
      return rewritten.replaceFirstMapped(
        headStart,
        (match) => '${match.group(0)}$head',
      );
    }
    return '<!doctype html><html><head>$head</head><body>$rewritten</body></html>';
  }

  static String _contentSecurityPolicy(bool requestInternetAccess) {
    final externalSources = requestInternetAccess ? ' https: http:' : '';
    return "default-src 'none'; base-uri 'none'; form-action 'none'; "
        "connect-src$externalSources; img-src data:$externalSources; "
        "media-src data:$externalSources; font-src data:$externalSources; "
        "style-src 'unsafe-inline' data:$externalSources; "
        "script-src 'unsafe-inline' data:$externalSources";
  }

  static String _shim(WebxdcWebBridgeConfig config) {
    final configJson = jsonEncode(<String, Object?>{
      'instanceId': config.instanceId,
      'token': config.token,
      'selfAddr': config.selfAddr,
      'selfName': config.selfName,
    }).replaceAll('</', r'<\/');

    return '''
(() => {
  'use strict';
  const config = $configJson;
  const channel = '${WebxdcWebMessage.channel}';
  const backlog = [];
  const importRequests = new Map();
  let listener = null;
  let nextRequestId = 0;

  const emit = (type, payload = {}) => {
    parent.postMessage(JSON.stringify({
      channel, type, instanceId: config.instanceId, token: config.token, ...payload,
    }), '*');
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

  window.addEventListener('message', (event) => {
    let message;
    try { message = JSON.parse(event.data); } catch (_) { return; }
    if (message.channel !== channel || message.instanceId !== config.instanceId ||
        message.token !== config.token) return;
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
        const raw = atob(file.base64);
        const bytes = Uint8Array.from(raw, (char) => char.charCodeAt(0));
        return new File([bytes], file.name, {type: file.contentType || ''});
      }));
    }
  });
  emit('ready');
})();
''';
  }
}
