// Unit tests for [LinuxWebxdcPlatform]'s non-widget behavior.
//
// These run entirely over loopback HTTP sockets under plain `flutter
// test` (no device/browser/native WebView). The widget-construction
// tests live separately in `linux_webxdc_platform_widget_test.dart`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_linux/flutter_webxdc_linux.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

Map<String, Uint8List> _files({String indexBody = '<html>hi</html>'}) => {
      'index.html': Uint8List.fromList(utf8.encode(indexBody)),
      'app.js': Uint8List.fromList(utf8.encode('console.log(1);')),
    };

Future<HttpClientResponse> _get(int port, String path) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    return await request.close();
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('LinuxWebxdcPlatform.loadApp', () {
    late LinuxWebxdcPlatform platform;

    tearDown(() async {
      await platform.disposeApp('instance-1');
    });

    test('serves index.html over a real loopback HTTP server', () async {
      platform = LinuxWebxdcPlatform();
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );

      expect(platform.pendingUpdateCount('instance-1'), 0);

      final response = await _get(platform.portOf('instance-1'), '/');
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(body, '<html>hi</html>');
    });

    test('rejects a file tree without index.html', () async {
      platform = LinuxWebxdcPlatform();
      await expectLater(
        platform.loadApp(
          instanceId: 'instance-1',
          files: {'style.css': Uint8List(0)},
          selfAddr: 'me@local',
          selfName: 'Me',
        ),
        throwsArgumentError,
      );
    });

    test('rejects loading the same instance twice', () async {
      platform = LinuxWebxdcPlatform();
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );
      await expectLater(
        platform.loadApp(
          instanceId: 'instance-1',
          files: _files(),
          selfAddr: 'me@local',
          selfName: 'Me',
        ),
        throwsStateError,
      );
    });

    test('applies the request_internet_access CSP contract', () async {
      platform = LinuxWebxdcPlatform();
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
        requestInternetAccess: true,
      );

      final response = await _get(platform.portOf('instance-1'), '/');
      final csp = response.headers.value('content-security-policy');
      expect(csp, contains('https:'));
      expect(csp, contains('wss:'));
    });

    test('blocks external origins by default in the CSP contract', () async {
      platform = LinuxWebxdcPlatform();
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );

      final response = await _get(platform.portOf('instance-1'), '/');
      final csp = response.headers.value('content-security-policy');
      expect(csp, isNot(contains('https:')));
      expect(csp, isNot(contains('wss:')));
    });
  });

  group('LinuxWebxdcPlatform.deliverUpdateToApp', () {
    test(
      'queues updates until the WebView controller exists',
      () async {
        final platform = LinuxWebxdcPlatform();
        addTearDown(() => platform.disposeApp('instance-1'));
        await platform.loadApp(
          instanceId: 'instance-1',
          files: _files(),
          selfAddr: 'me@local',
          selfName: 'Me',
        );

        const update = WebxdcUpdate(
          payload: {'counter': 1},
          serial: 1,
          maxSerial: 1,
        );
        await platform.deliverUpdateToApp('instance-1', update);

        expect(platform.pendingUpdateCount('instance-1'), 1);
      },
    );

    test('does nothing for an instance that was never loaded', () async {
      final platform = LinuxWebxdcPlatform();
      const update = WebxdcUpdate(
        payload: {'counter': 1},
        serial: 1,
        maxSerial: 1,
      );
      await platform.deliverUpdateToApp('missing-instance', update);
    });
  });

  group('LinuxWebxdcPlatform.sendToChat', () {
    late LinuxWebxdcPlatform platform;

    setUp(() async {
      platform = LinuxWebxdcPlatform();
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );
    });

    tearDown(() => platform.disposeApp('instance-1'));

    test(
      'emits a WebxdcJsSendToChatEvent and records it in the log',
      () async {
        final events = <WebxdcJsSendToChatEvent>[];
        final sub = platform.sendToChatEvents.listen(events.add);
        addTearDown(sub.cancel);

        await platform.sendToChat(instanceId: 'instance-1', text: 'hello');
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.single.text, 'hello');
        expect(platform.sendToChatLog('instance-1'), events);
      },
    );

    test('rejects a request with neither text nor file bytes', () async {
      await expectLater(
        platform.sendToChat(instanceId: 'instance-1'),
        throwsArgumentError,
      );
    });
  });

  group('LinuxWebxdcPlatform.importFiles', () {
    test('delegates to the configured file picker', () async {
      List<String>? pickedExtensions;
      List<String>? pickedMimeTypes;
      bool? pickedMultiple;

      final platform = LinuxWebxdcPlatform(
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
      addTearDown(() => platform.disposeApp('instance-1'));
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );

      final files = await platform.importFiles(
        instanceId: 'instance-1',
        extensions: ['txt', '.md'],
        mimeTypes: ['text/plain'],
        multiple: true,
      );

      expect(files, hasLength(1));
      expect(files.single.name, 'picked.txt');
      expect(pickedExtensions, ['txt', '.md']);
      expect(pickedMimeTypes, ['text/plain']);
      expect(pickedMultiple, isTrue);
    });

    test('throws for an instance that was never loaded', () async {
      final platform = LinuxWebxdcPlatform();
      await expectLater(
        platform.importFiles(instanceId: 'missing-instance'),
        throwsStateError,
      );
    });
  });

  group('LinuxWebxdcPlatform.disposeApp', () {
    test('stops the HTTP server so the port stops responding', () async {
      final platform = LinuxWebxdcPlatform();
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );
      final port = platform.portOf('instance-1');

      await platform.disposeApp('instance-1');

      await expectLater(_get(port, '/'), throwsA(isA<SocketException>()));
    });
  });
}
