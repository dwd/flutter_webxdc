// Unit tests for [WebxdcServer], the loopback HTTP host used to serve an
// extracted `.xdc` app's files to the native WebView.
//
// These tests run entirely over `HttpClient`/loopback sockets under plain
// `flutter test` (no device/browser/WebView required), and specifically
// cover the behaviors called out in doc/design.md's network-isolation
// contract: the `/` -> `index.html` rewrite, 404s for unknown paths,
// per-extension content types, and — importantly — that the
// Content-Security-Policy header actually changes shape depending on
// `request_internet_access`, rather than always denying external network
// access regardless of the flag.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_webview/src/webxdc_server.dart';

void main() {
  group('WebxdcServer', () {
    late WebxdcServer server;

    Map<String, Uint8List> files() => {
          'index.html': Uint8List.fromList(utf8.encode('<html></html>')),
          'app.js': Uint8List.fromList(utf8.encode('console.log(1);')),
          'style.css': Uint8List.fromList(utf8.encode('body{}')),
          'icon.png': Uint8List.fromList([1, 2, 3, 4]),
        };

    Future<HttpClientResponse> get(String path) async {
      final client = HttpClient();
      try {
        final request = await client.get('127.0.0.1', server.port, path);
        return await request.close();
      } finally {
        client.close(force: true);
      }
    }

    tearDown(() async {
      await server.stop();
    });

    test('serves the root path as index.html', () async {
      server = WebxdcServer(files());
      await server.start();

      final response = await get('/');
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, '<html></html>');
      expect(response.headers.contentType?.mimeType, 'text/html');
    });

    test('serves nested/known files with the correct content type', () async {
      server = WebxdcServer(files());
      await server.start();

      final jsResponse = await get('/app.js');
      expect(jsResponse.statusCode, HttpStatus.ok);
      expect(
          jsResponse.headers.contentType?.mimeType, 'application/javascript');

      final cssResponse = await get('/style.css');
      expect(cssResponse.statusCode, HttpStatus.ok);
      expect(cssResponse.headers.contentType?.mimeType, 'text/css');

      final pngResponse = await get('/icon.png');
      expect(pngResponse.statusCode, HttpStatus.ok);
      expect(pngResponse.headers.contentType?.mimeType, 'image/png');
    });

    test('returns 404 for unknown paths', () async {
      server = WebxdcServer(files());
      await server.start();

      final response = await get('/does-not-exist.html');

      expect(response.statusCode, HttpStatus.notFound);
    });

    test('denies external network access by default via CSP header', () async {
      server = WebxdcServer(files(), requestInternetAccess: false);
      await server.start();

      final response = await get('/');
      final csp = response.headers.value('content-security-policy');

      expect(csp, isNotNull);
      expect(csp, contains("connect-src 'self' data: blob:;"));
      expect(csp, isNot(contains('https:')));
      expect(csp, isNot(contains('wss:')));
    });

    test(
        'widens the CSP to allow external network access when '
        'request_internet_access is true', () async {
      server = WebxdcServer(files(), requestInternetAccess: true);
      await server.start();

      final response = await get('/');
      final csp = response.headers.value('content-security-policy');

      expect(csp, isNotNull);
      expect(csp, contains('connect-src'));
      expect(csp, contains('https:'));
      expect(csp, contains('wss:'));
    });
  });

  group('WebxdcServer.buildContentSecurityPolicy', () {
    test('blocks external connect-src/img-src/frame-src by default', () {
      final csp = WebxdcServer.buildContentSecurityPolicy(false);

      expect(csp, contains("connect-src 'self' data: blob:;"));
      expect(csp, contains("img-src 'self' data: blob:;"));
      expect(csp, contains("frame-src 'self';"));
      expect(csp, isNot(contains('https:')));
    });

    test('allows https:/wss: origins when request_internet_access is true', () {
      final csp = WebxdcServer.buildContentSecurityPolicy(true);

      expect(csp, contains('connect-src'));
      expect(csp, contains('https:'));
      expect(csp, contains('wss:'));
      expect(csp, contains('img-src'));
      expect(csp, contains('frame-src'));
    });
  });
}
