import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_web/flutter_webxdc_web.dart';

void main() {
  group('WebxdcWebMessage', () {
    test('round-trips a versioned message and its payload', () {
      const message = WebxdcWebMessage(
        type: 'sendUpdate',
        instanceId: 'chat-42',
        token: 'secret',
        payload: <String, Object?>{
          'update': <String, Object?>{'payload': 7},
          'descr': 'bumped',
        },
      );

      final decoded = WebxdcWebMessage.tryDecode(message.encode());

      expect(decoded?.type, 'sendUpdate');
      expect(decoded?.instanceId, 'chat-42');
      expect(decoded?.token, 'secret');
      expect(decoded?.payload['descr'], 'bumped');
      expect(decoded?.payload['update'], <String, Object?>{'payload': 7});
    });

    test('rejects malformed or unrelated browser messages', () {
      expect(WebxdcWebMessage.tryDecode(42), isNull);
      expect(WebxdcWebMessage.tryDecode('{'), isNull);
      expect(
        WebxdcWebMessage.tryDecode(
          jsonEncode(<String, Object?>{
            'channel': 'another-channel',
            'type': 'ready',
            'instanceId': 'app',
            'token': 'secret',
          }),
        ),
        isNull,
      );
      expect(
        WebxdcWebMessage.tryDecode(
          jsonEncode(<String, Object?>{
            'channel': WebxdcWebMessage.channel,
            'type': 'ready',
            'instanceId': 'app',
          }),
        ),
        isNull,
      );
    });
  });

  group('WebxdcWebDocumentBuilder', () {
    const config = WebxdcWebBridgeConfig(
      instanceId: 'app',
      token: 'bridge-token',
      selfAddr: 'me@example',
      selfName: 'Me',
      requestInternetAccess: false,
    );

    test('injects the bridge and rewrites only declared archive assets', () {
      final document = WebxdcWebDocumentBuilder.build(
        indexHtml: '''
<html><head><script src="scripts/app.js"></script></head>
<body><img src="./image.png"><a href="https://example.invalid">link</a></body>
</html>''',
        assetUrls: const <String, String>{
          'scripts/app.js': 'data:text/javascript;base64,YQ==',
          'image.png': 'data:image/png;base64,Yg==',
        },
        config: config,
      );

      expect(document, contains('data:text/javascript;base64,YQ=='));
      expect(document, contains('data:image/png;base64,Yg=='));
      expect(document, contains('href="https://example.invalid"'));
      expect(document, contains('window.webxdc = Object.freeze'));
      expect(
        document.indexOf('window.webxdc = Object.freeze'),
        lessThan(document.indexOf('data:text/javascript;base64,YQ==')),
      );
      expect(document, contains('"selfAddr":"me@example"'));
      expect(document, contains("connect-src;"));
      expect(document, isNot(contains("sandbox")));
    });

    test('permits external sources only with manifest internet access', () {
      final offline = WebxdcWebDocumentBuilder.build(
        indexHtml: '<html><head></head><body></body></html>',
        assetUrls: const <String, String>{},
        config: config,
      );
      final online = WebxdcWebDocumentBuilder.build(
        indexHtml: '<html><head></head><body></body></html>',
        assetUrls: const <String, String>{},
        config: const WebxdcWebBridgeConfig(
          instanceId: 'app',
          token: 'bridge-token',
          selfAddr: 'me@example',
          selfName: 'Me',
          requestInternetAccess: true,
        ),
      );

      expect(offline, isNot(contains('connect-src https: http:')));
      expect(online, contains('connect-src https: http:'));
    });

    test('wraps documents without a head in a valid bridge document', () {
      final document = WebxdcWebDocumentBuilder.build(
        indexHtml: '<p>Standalone</p>',
        assetUrls: const <String, String>{},
        config: config,
      );

      expect(document, startsWith('<!doctype html><html><head>'));
      expect(document, contains('<p>Standalone</p>'));
    });

    test('injects a default viewport meta tag when the app has none, so the '
        'sandboxed iframe always matches its real rendered size', () {
      final document = WebxdcWebDocumentBuilder.build(
        indexHtml: '<html><head></head><body></body></html>',
        assetUrls: const <String, String>{},
        config: config,
      );

      expect(document, contains('name="viewport"'));
      expect(document, contains('width=device-width'));
    });

    test("doesn't duplicate an app-supplied viewport meta tag", () {
      final document = WebxdcWebDocumentBuilder.build(
        indexHtml:
            '<html><head><meta name="viewport" '
            'content="width=320"></head><body></body></html>',
        assetUrls: const <String, String>{},
        config: config,
      );

      expect('viewport'.allMatches(document).length, 1);
      expect(document, contains('width=320'));
    });
  });
}
