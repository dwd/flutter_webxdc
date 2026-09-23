@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_web/flutter_webxdc_web.dart';

void main() {
  testWidgets('buildHostWidget returns an HtmlElementView for a loaded app', (
    tester,
  ) async {
    final platform = WebWebxdcPlatform();
    await platform.loadApp(
      instanceId: 'web-app',
      files: <String, Uint8List>{
        'index.html': Uint8List.fromList(
          '<html><body>hi</body></html>'.codeUnits,
        ),
      },
      selfAddr: 'me@example',
      selfName: 'Me',
    );

    final widget = platform.buildHostWidget('web-app');

    expect(widget, isA<HtmlElementView>());

    await platform.disposeApp('web-app');
  });
}
