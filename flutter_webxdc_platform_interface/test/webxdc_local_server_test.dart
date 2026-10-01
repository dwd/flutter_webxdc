// Unit tests for [WebxdcLocalServer.injectViewportMetaIfMissing], the
// fallback used to give hosted apps a sane default `<meta name="viewport">`
// when their own `index.html` doesn't declare one (see doc/design.md §2/§6:
// some WebView engines otherwise lay the page out at a desktop-style
// default viewport width regardless of the actual rendered size).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

Uint8List _bytes(String html) => Uint8List.fromList(utf8.encode(html));

void main() {
  group('WebxdcLocalServer.injectViewportMetaIfMissing', () {
    test(
      'inserts the default viewport meta right after an existing <head>',
      () {
        final result = WebxdcLocalServer.injectViewportMetaIfMissing(
          _bytes('<html><head><title>App</title></head><body></body></html>'),
        );

        expect(
          utf8.decode(result),
          '<html><head>'
          '<meta name="viewport" content="width=device-width, initial-scale=1">'
          '<title>App</title></head><body></body></html>',
        );
      },
    );

    test('prepends the meta tag when the document has no <head> at all', () {
      final result = WebxdcLocalServer.injectViewportMetaIfMissing(
        _bytes('<html></html>'),
      );

      expect(
        utf8.decode(result),
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<html></html>',
      );
    });

    test('leaves the bytes unchanged when a viewport meta already exists', () {
      const html =
          '<html><head><meta name="viewport" '
          'content="width=320, initial-scale=2"></head></html>';
      final original = _bytes(html);

      final result = WebxdcLocalServer.injectViewportMetaIfMissing(original);

      expect(identical(result, original), isTrue);
      expect(utf8.decode(result), html);
    });

    test('detects an existing viewport meta regardless of attribute order', () {
      const html =
          '<html><head><meta content="width=device-width" '
          'name="viewport"></head></html>';
      final original = _bytes(html);

      final result = WebxdcLocalServer.injectViewportMetaIfMissing(original);

      expect(utf8.decode(result), html);
    });
  });
}
