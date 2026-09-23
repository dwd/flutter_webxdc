// Unit tests for MemoryWebxdcPlatform — the first concrete WebxdcPlatform
// implementation. Runs under plain `flutter test` with no device/browser.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_memory/flutter_webxdc_memory.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

void main() {
  late MemoryWebxdcPlatform platform;

  final indexHtml = Uint8List.fromList(utf8.encode('<html></html>'));
  final minimalFiles = <String, Uint8List>{'index.html': indexHtml};

  setUp(() {
    WebxdcPlatform.resetInstanceForTesting();
    platform = MemoryWebxdcPlatform();
    WebxdcPlatform.instance = platform;
  });

  tearDown(() {
    platform.resetAppsForTesting();
    WebxdcPlatform.resetInstanceForTesting();
  });

  group('registerWith', () {
    test('installs a MemoryWebxdcPlatform as WebxdcPlatform.instance', () {
      WebxdcPlatform.resetInstanceForTesting();
      MemoryWebxdcPlatform.registerWith();

      expect(WebxdcPlatform.instance, isA<MemoryWebxdcPlatform>());
    });
  });

  group('loadApp / disposeApp', () {
    test('loads and tracks an app instance', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me@local',
        selfName: 'Me',
        requestInternetAccess: true,
      );

      expect(platform.isLoaded('a'), isTrue);
      expect(platform.selfAddrOf('a'), 'me@local');
      expect(platform.selfNameOf('a'), 'Me');
      expect(platform.requestInternetAccessOf('a'), isTrue);
      expect(platform.filesOf('a')['index.html'], indexHtml);
    });

    test('rejects a second load of the same instanceId', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );

      await expectLater(
        () => platform.loadApp(
          instanceId: 'a',
          files: minimalFiles,
          selfAddr: 'me',
          selfName: 'Me',
        ),
        throwsStateError,
      );
    });

    test('rejects files without index.html', () async {
      await expectLater(
        () => platform.loadApp(
          instanceId: 'a',
          files: <String, Uint8List>{'other.txt': Uint8List(0)},
          selfAddr: 'me',
          selfName: 'Me',
        ),
        throwsArgumentError,
      );
    });

    test('disposeApp drops the instance', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );
      await platform.disposeApp('a');

      expect(platform.isLoaded('a'), isFalse);
      expect(() => platform.filesOf('a'), throwsStateError);
    });
  });

  group('deliverUpdateToApp', () {
    test('appends updates in order for the instance', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );

      const first = WebxdcUpdate(payload: 1, serial: 1, maxSerial: 1);
      const second = WebxdcUpdate(payload: 2, serial: 2, maxSerial: 2);
      await platform.deliverUpdateToApp('a', first);
      await platform.deliverUpdateToApp('a', second);

      expect(platform.deliveredUpdates('a'), [first, second]);
    });

    test('throws when the instance is not loaded', () async {
      await expectLater(
        () => platform.deliverUpdateToApp(
          'missing',
          const WebxdcUpdate(payload: 1, serial: 1, maxSerial: 1),
        ),
        throwsStateError,
      );
    });
  });

  group('simulateJsSendUpdate / sendUpdateEvents', () {
    test('emits a WebxdcJsSendUpdateEvent for the instance', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );

      final events = <WebxdcJsSendUpdateEvent>[];
      final sub = platform.sendUpdateEvents.listen(events.add);

      platform.simulateJsSendUpdate('a', {
        'payload': {'counter': 1},
      }, descr: 'bumped');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.instanceId, 'a');
      expect(events.single.update['payload'], {'counter': 1});
      expect(events.single.descr, 'bumped');
      await sub.cancel();
    });

    test('throws when the instance is not loaded', () {
      expect(
        () => platform.simulateJsSendUpdate('missing', {'payload': 1}),
        throwsStateError,
      );
    });
  });

  group('sendToChat', () {
    test('records and emits a sendToChat event', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );

      final events = <WebxdcJsSendToChatEvent>[];
      final sub = platform.sendToChatEvents.listen(events.add);

      await platform.sendToChat(instanceId: 'a', text: 'hello');
      await Future<void>.delayed(Duration.zero);

      expect(platform.sendToChatLog('a'), hasLength(1));
      expect(platform.sendToChatLog('a').single.text, 'hello');
      expect(events, hasLength(1));
      expect(events.single.text, 'hello');
      await sub.cancel();
    });

    test('requires text or fileBytes', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );

      await expectLater(
        () => platform.sendToChat(instanceId: 'a'),
        throwsArgumentError,
      );
    });
  });

  group('importFiles', () {
    test('returns an empty list when nothing is queued', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );

      final files = await platform.importFiles(instanceId: 'a');
      expect(files, isEmpty);
    });

    test('returns and clears queued files', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );
      platform.queueImportedFiles('a', [
        WebxdcImportedFile(name: 'a.txt', bytes: Uint8List.fromList([1])),
        WebxdcImportedFile(name: 'b.txt', bytes: Uint8List.fromList([2])),
      ]);

      final first = await platform.importFiles(instanceId: 'a', multiple: true);
      expect(first, hasLength(2));
      expect(first.first.name, 'a.txt');

      final second = await platform.importFiles(instanceId: 'a');
      expect(second, isEmpty);
    });

    test('honours multiple: false by returning only the first file', () async {
      await platform.loadApp(
        instanceId: 'a',
        files: minimalFiles,
        selfAddr: 'me',
        selfName: 'Me',
      );
      platform.queueImportedFiles('a', [
        WebxdcImportedFile(name: 'a.txt', bytes: Uint8List.fromList([1])),
        WebxdcImportedFile(name: 'b.txt', bytes: Uint8List.fromList([2])),
      ]);

      final files = await platform.importFiles(instanceId: 'a');
      expect(files, hasLength(1));
      expect(files.single.name, 'a.txt');
    });
  });

  group('supportsRealtimeChannel', () {
    test('defaults to false', () {
      expect(platform.supportsRealtimeChannel, isFalse);
    });
  });
}
