import 'dart:io';
import 'dart:typed_data';

class WebxdcServer {
  final Map<String, Uint8List> files;
  final bool requestInternetAccess;
  HttpServer? _server;
  int _port = 0;

  WebxdcServer(this.files, {this.requestInternetAccess = false});

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
    switch (ext) {
      case 'html':
      case 'htm':
        mimeType = 'text/html';
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

    request.response.add(fileData);
    request.response.close();
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
