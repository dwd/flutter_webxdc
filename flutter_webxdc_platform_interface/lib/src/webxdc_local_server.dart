import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Loopback-only HTTP host for an already-extracted `.xdc` file tree.
///
/// Shared by platform implementations that need to serve `.xdc` assets to
/// a renderer over `http://127.0.0.1:<port>/` instead of (or in addition
/// to) embedding a WebView directly — e.g. `flutter_webxdc_webview`
/// (native `InAppWebView`) and `flutter_webxdc_linux` (no embeddable
/// in-app WebView available, so the served URL is opened in the system
/// browser instead, see doc/design.md §2/§3).
///
/// Enforces the network-isolation contract from `doc/design.md` §3 via a
/// `Content-Security-Policy` response header built by
/// [buildContentSecurityPolicy].
class WebxdcLocalServer {
  final Map<String, Uint8List> files;
  final bool requestInternetAccess;
  HttpServer? _server;
  int _port = 0;

  WebxdcLocalServer(this.files, {this.requestInternetAccess = false});

  int get port => _port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen((HttpRequest request) {
      _handleRequest(request);
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _handleRequest(HttpRequest request) {
    var path = request.uri.path;
    if (path == '/') {
      path = '/index.html';
    }
    path = path.startsWith('/') ? path.substring(1) : path;

    final fileData = files[path];
    if (fileData == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      request.response.close();
      return;
    }

    final ext = path.split('.').last.toLowerCase();
    String mimeType = 'application/octet-stream';
    var responseData = fileData;
    switch (ext) {
      case 'html':
      case 'htm':
        mimeType = 'text/html';
        responseData = injectViewportMetaIfMissing(fileData);
        break;
      case 'js':
        mimeType = 'application/javascript';
        break;
      case 'css':
        mimeType = 'text/css';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'svg':
        mimeType = 'image/svg+xml';
        break;
      case 'json':
        mimeType = 'application/json';
        break;
    }

    request.response.headers.contentType = ContentType.parse(mimeType);
    request.response.headers.add(
      'Content-Security-Policy',
      buildContentSecurityPolicy(requestInternetAccess),
    );

    request.response.add(responseData);
    request.response.close();
  }

  /// A sensible default `<meta name="viewport">` tag, used when a hosted
  /// app's `index.html` doesn't already define one.
  ///
  /// Without this, some WebView engines lay out pages at a desktop-style
  /// default viewport width (historically ~980px) regardless of the actual
  /// rendered size, which makes a small embedded card look/behave like a
  /// tiny window onto a much larger page instead of a genuinely small page.
  /// See doc/design.md §2/§6 for the full rationale.
  static const String defaultViewportMetaTag =
      '<meta name="viewport" content="width=device-width, initial-scale=1">';

  static final RegExp _viewportMetaPattern = RegExp(
    '''<meta[^>]+name\\s*=\\s*["']viewport["']''',
    caseSensitive: false,
  );

  static final RegExp _headOpenTagPattern = RegExp(
    r'<head\b[^>]*>',
    caseSensitive: false,
  );

  /// Returns [htmlBytes] unchanged if it already declares a `viewport`
  /// meta tag, otherwise returns a copy with [defaultViewportMetaTag]
  /// inserted right after the opening `<head>` tag (or prepended if the
  /// document has no `<head>` at all).
  @visibleForTesting
  static Uint8List injectViewportMetaIfMissing(Uint8List htmlBytes) {
    final html = utf8.decode(htmlBytes, allowMalformed: true);
    if (_viewportMetaPattern.hasMatch(html)) {
      return htmlBytes;
    }
    final headMatch = _headOpenTagPattern.firstMatch(html);
    final injected = headMatch != null
        ? html.replaceRange(
            headMatch.end,
            headMatch.end,
            defaultViewportMetaTag,
          )
        : '$defaultViewportMetaTag$html';
    return Uint8List.fromList(utf8.encode(injected));
  }

  /// Builds the `Content-Security-Policy` header value used for every
  /// response served by this server.
  ///
  /// Mirrors the network-isolation contract documented in `doc/design.md`:
  /// by default all outgoing network access is blocked (`connect-src`,
  /// `img-src`, `media-src`, and `frame-src` are restricted to `'self'`
  /// plus local `data:`/`blob:` URIs). When [requestInternetAccess] is
  /// `true` (i.e. the app's `manifest.toml` sets
  /// `request_internet_access = true`), those directives are widened to
  /// allow `https:`/`wss:` origins as well, so the flag has an actual
  /// effect instead of always denying external network access.
  static String buildContentSecurityPolicy(bool requestInternetAccess) {
    if (requestInternetAccess) {
      return "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: "
          "https:; "
          "connect-src 'self' data: blob: https: wss:; "
          "img-src 'self' data: blob: https:; "
          "media-src 'self' data: blob: https:; "
          "frame-src 'self' https:;";
    }
    return "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; "
        "connect-src 'self' data: blob:; "
        "img-src 'self' data: blob:; "
        "media-src 'self' data: blob:; "
        "frame-src 'self';";
  }
}
