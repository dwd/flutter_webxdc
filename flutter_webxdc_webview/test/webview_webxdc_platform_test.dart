import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_webview/flutter_webxdc_webview.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebviewWebxdcPlatform', () {
    late List<String>? pickedExtensions;
    late List<String>? pickedMimeTypes;
    late bool pickedMultiple;
    late WebviewWebxdcPlatform platform;

    setUp(() {
      pickedExtensions = null;
      pickedMimeTypes = null;
      pickedMultiple = false;
      platform = WebviewWebxdcPlatform(
        filePicker: ({extensions, mimeTypes, multiple = false}) async {
          pickedExtensions = extensions;
          pickedMimeTypes = mimeTypes;
          pickedMultiple = multiple;
          return [
            WebxdcImportedFile(
              name: 'picked.txt',
              bytes: Uint8List.fromList([1, 2, 3]),
              contentType: 'text/plain',
            ),
          ];
        },
      );
    });

    test(
        'loadApp starts server, buildHostWidget works, and disposeApp stops it',
        () async {
      const instanceId = 'test-instance';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList([1, 2, 3])
        },
        selfAddr: 'addr@local',
        selfName: 'Tester',
      );

      expect(platform.buildHostWidget(instanceId), isNotNull);

      // Dispose should close the server and remove the app.
      await platform.disposeApp(instanceId);
    });

    test('deliverUpdateToApp queues updates until the WebView exists',
        () async {
      const instanceId = 'queued-update';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList([1, 2, 3])
        },
        selfAddr: 'addr@local',
        selfName: 'Tester',
      );

      await platform.deliverUpdateToApp(
        instanceId,
        const WebxdcUpdate(payload: {'counter': 1}, serial: 1, maxSerial: 1),
      );

      expect(platform.pendingUpdateCount(instanceId), 1);
      await platform.disposeApp(instanceId);
    });

    test('sendToChat emits the request on the shared stream', () async {
      const instanceId = 'send-to-chat';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList([1, 2, 3])
        },
        selfAddr: 'addr@local',
        selfName: 'Tester',
      );

      final requests = <WebxdcJsSendToChatEvent>[];
      final sub = platform.sendToChatEvents.listen(requests.add);
      await platform.sendToChat(
        instanceId: instanceId,
        text: 'forward me',
        fileBytes: Uint8List.fromList([9, 8, 7]),
        fileName: 'note.txt',
        contentType: 'text/plain',
      );

      expect(requests, hasLength(1));
      expect(requests.single.text, 'forward me');
      expect(requests.single.fileName, 'note.txt');
      expect(requests.single.contentType, 'text/plain');
      expect(requests.single.fileBytes, [9, 8, 7]);

      await sub.cancel();
      await platform.disposeApp(instanceId);
    });

    test('sendToChat rejects empty requests', () async {
      const instanceId = 'empty-send-to-chat';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList([1, 2, 3])
        },
        selfAddr: 'addr@local',
        selfName: 'Tester',
      );

      await expectLater(
        () => platform.sendToChat(instanceId: instanceId),
        throwsArgumentError,
      );

      await platform.disposeApp(instanceId);
    });

    test('importFiles delegates to the configured picker', () async {
      const instanceId = 'import';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList([1, 2, 3])
        },
        selfAddr: 'addr@local',
        selfName: 'Tester',
      );

      final files = await platform.importFiles(
        instanceId: instanceId,
        extensions: ['txt', '.md'],
        mimeTypes: ['text/plain'],
        multiple: true,
      );

      expect(files, hasLength(1));
      expect(files.single.name, 'picked.txt');
      expect(files.single.contentType, 'text/plain');
      expect(pickedExtensions, ['txt', '.md']);
      expect(pickedMimeTypes, ['text/plain']);
      expect(pickedMultiple, isTrue);

      await platform.disposeApp(instanceId);
    });
  });
}
