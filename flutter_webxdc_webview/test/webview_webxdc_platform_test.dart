import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_webview/flutter_webxdc_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebviewWebxdcPlatform', () {
    late WebviewWebxdcPlatform platform;

    setUp(() {
      platform = WebviewWebxdcPlatform();
    });

    test('loadApp starts server and disposeApp stops it', () async {
      const instanceId = 'test-instance';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList([1, 2, 3])
        },
        selfAddr: 'addr@local',
        selfName: 'Tester',
      );

      // Dispose should close the server and remove the app.
      await platform.disposeApp(instanceId);
    });
  });
}
