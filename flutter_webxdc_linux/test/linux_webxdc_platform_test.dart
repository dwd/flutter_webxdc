// Unit tests for [LinuxWebxdcPlatform]'s non-widget behavior.
//
// These run entirely over loopback HTTP sockets under plain `flutter
// test` (no device/browser/WebView). Deliberately kept in a
// `testWidgets`-free file: `TestWidgetsFlutterBinding` intercepts real
// `Timer`s created by `HttpServer.bind` inside `testWidgets`, so the
// widget-rendering test lives separately in
// `linux_webxdc_platform_widget_test.dart` and uses `tester.runAsync`.
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

      final url = platform.urlOf('instance-1');
      expect(url.host, '127.0.0.1');

      final response = await _get(url.port, '/');
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

      final url = platform.urlOf('instance-1');
      final response = await _get(url.port, '/');
      final csp = response.headers.value('content-security-policy');
      expect(csp, contains('https:'));
      expect(csp, contains('wss:'));
    });
  });

  group('LinuxWebxdcPlatform.deliverUpdateToApp', () {
    test(
      'records updates for inspection even without a live JS bridge',
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

        expect(platform.deliveredUpdates('instance-1'), [update]);
      },
    );
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
    test('returns an empty list (no native picker wired up yet)', () async {
      final platform = LinuxWebxdcPlatform();
      addTearDown(() => platform.disposeApp('instance-1'));
      await platform.loadApp(
        instanceId: 'instance-1',
        files: _files(),
        selfAddr: 'me@local',
        selfName: 'Me',
      );

      final files = await platform.importFiles(instanceId: 'instance-1');
      expect(files, isEmpty);
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
      final url = platform.urlOf('instance-1');

      await platform.disposeApp('instance-1');

      await expectLater(_get(url.port, '/'), throwsA(isA<SocketException>()));
    });
  });
}
