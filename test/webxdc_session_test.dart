// Integration-style unit tests for WebxdcSession: wires WebxdcArchive +
// WebxdcController to MemoryWebxdcPlatform under plain `flutter test`
// (no device/browser), exercising the federated plugin path end-to-end.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc/flutter_webxdc.dart';

Uint8List _buildXdcZip({required String indexHtml, String? manifestToml}) {
  final archive = Archive();
  final indexBytes = Uint8List.fromList(utf8.encode(indexHtml));
  archive.addFile(ArchiveFile('index.html', indexBytes.length, indexBytes));
  if (manifestToml != null) {
    final manifestBytes = Uint8List.fromList(utf8.encode(manifestToml));
    archive.addFile(
      ArchiveFile('manifest.toml', manifestBytes.length, manifestBytes),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late MemoryWebxdcPlatform platform;

  setUp(() {
    WebxdcPlatform.resetInstanceForTesting();
    platform = MemoryWebxdcPlatform();
    FlutterWebxdc.ensureInitialized(platform: platform);
  });

  tearDown(() {
    platform.resetAppsForTesting();
    WebxdcPlatform.resetInstanceForTesting();
  });

  group('FlutterWebxdc.ensureInitialized', () {
    test('installs MemoryWebxdcPlatform when nothing is registered', () {
      WebxdcPlatform.resetInstanceForTesting();
      FlutterWebxdc.ensureInitialized();

      expect(WebxdcPlatform.instance, isA<MemoryWebxdcPlatform>());
    });

    test('is a no-op when something is already registered', () {
      final first = WebxdcPlatform.instance;
      FlutterWebxdc.ensureInitialized();
      expect(WebxdcPlatform.instance, same(first));
    });

    test('installs an explicitly supplied platform', () {
      final other = MemoryWebxdcPlatform();
      FlutterWebxdc.ensureInitialized(platform: other);
      expect(WebxdcPlatform.instance, same(other));
    });
  });

  group('WebxdcSession.open', () {
    test(
      'loads the archive onto the platform and exposes the controller',
      () async {
        final bytes = _buildXdcZip(
          indexHtml: '<html><body>hi</body></html>',
          manifestToml:
              'name = "Session Fixture"\n'
              'request_internet_access = true\n',
        );

        final session = await WebxdcSession.open(
          xdcBytes: bytes,
          instanceId: 'chat-1',
          selfAddr: 'me@local',
          selfName: 'Me',
        );

        expect(session.instanceId, 'chat-1');
        expect(session.archive.manifest?.name, 'Session Fixture');
        expect(platform.isLoaded('chat-1'), isTrue);
        expect(platform.selfAddrOf('chat-1'), 'me@local');
        expect(platform.selfNameOf('chat-1'), 'Me');
        expect(platform.requestInternetAccessOf('chat-1'), isTrue);
        expect(platform.filesOf('chat-1').containsKey('index.html'), isTrue);

        await session.dispose();
        expect(platform.isLoaded('chat-1'), isFalse);
      },
    );

    test(
      'defaults requestInternetAccess to false when manifest omits it',
      () async {
        final bytes = _buildXdcZip(
          indexHtml: '<html></html>',
          manifestToml: 'name = "No Net"\n',
        );

        final session = await WebxdcSession.open(
          xdcBytes: bytes,
          instanceId: 'chat-2',
          selfAddr: 'me',
          selfName: 'Me',
        );

        expect(platform.requestInternetAccessOf('chat-2'), isFalse);
        await session.dispose();
      },
    );
  });

  group('WebxdcSession update round-trip', () {
    late WebxdcSession session;

    setUp(() async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'round-trip',
        selfAddr: 'me@local',
        selfName: 'Me',
      );
    });

    tearDown(() async {
      await session.dispose();
    });

    test(
      'host sendUpdate is recorded and delivered into the platform',
      () async {
        final received = <WebxdcUpdate>[];
        final sub = session.updates.listen(received.add);

        final update = session.sendUpdate({
          'payload': {'counter': 1},
          'info': 'bumped',
        });
        await Future<void>.delayed(Duration.zero);

        expect(update.serial, 1);
        expect(received, hasLength(1));
        expect(received.single.payload, {'counter': 1});
        expect(platform.deliveredUpdates('round-trip'), hasLength(1));
        expect(platform.deliveredUpdates('round-trip').single.serial, 1);

        await sub.cancel();
      },
    );

    test('peer deliverPeerUpdate is delivered into the platform', () async {
      session.deliverPeerUpdate({'payload': 'from-peer'});
      await Future<void>.delayed(Duration.zero);

      expect(platform.deliveredUpdates('round-trip'), hasLength(1));
      expect(
        platform.deliveredUpdates('round-trip').single.payload,
        'from-peer',
      );
    });

    test(
      'JS-originated sendUpdate flows through controller into platform',
      () async {
        // Simulate mini-app JS calling window.webxdc.sendUpdate.
        platform.simulateJsSendUpdate('round-trip', {
          'payload': {'counter': 7},
        }, descr: 'from-js');
        // Allow the sendUpdateEvents subscription to run, then the
        // controller.updates -> deliverUpdateToApp subscription.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(session.controller.maxSerial, 1);
        expect(session.controller.updatesSince(0).single.info, 'from-js');
        expect(platform.deliveredUpdates('round-trip'), hasLength(1));
        expect(platform.deliveredUpdates('round-trip').single.payload, {
          'counter': 7,
        });
      },
    );
  });

  group('WebxdcSession sendToChat / importFiles', () {
    test('exposes JS sendToChat requests through the session', () async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      final session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'send-to-chat',
        selfAddr: 'me',
        selfName: 'Me',
      );

      final requests = <WebxdcJsSendToChatEvent>[];
      final sub = session.sendToChatRequests.listen(requests.add);

      platform.simulateJsSendToChat(
        'send-to-chat',
        text: 'forward me',
        fileBytes: Uint8List.fromList(utf8.encode('hi')),
        fileName: 'hello.txt',
        contentType: 'text/plain',
      );
      await Future<void>.delayed(Duration.zero);

      expect(requests, hasLength(1));
      expect(requests.single.text, 'forward me');
      expect(requests.single.fileName, 'hello.txt');
      expect(requests.single.contentType, 'text/plain');

      await sub.cancel();
      await session.dispose();
    });

    test('forwards sendToChat to the platform', () async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      final session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'share',
        selfAddr: 'me',
        selfName: 'Me',
      );

      await session.sendToChat(text: 'hello peer');
      expect(platform.sendToChatLog('share').single.text, 'hello peer');

      await session.dispose();
    });

    test('forwards importFiles to the platform', () async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      final session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'import',
        selfAddr: 'me',
        selfName: 'Me',
      );

      platform.queueImportedFiles('import', [
        WebxdcImportedFile(
          name: 'note.txt',
          bytes: Uint8List.fromList(utf8.encode('hi')),
        ),
      ]);

      final files = await session.importFiles();
      expect(files, hasLength(1));
      expect(files.single.name, 'note.txt');

      await session.dispose();
    });
  });

  group('WebxdcSession render surface', () {
    test('buildHostWidget returns the registered platform widget', () async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      final session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'host-widget',
        selfAddr: 'me',
        selfName: 'Me',
      );

      final widget = session.buildHostWidget();

      expect(widget, isNotNull);

      await session.dispose();
    });

    test('WebxdcHostView stores the session and host key', () async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      final session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'host-view',
        selfAddr: 'me',
        selfName: 'Me',
      );

      const hostKey = Key('host-key');
      final view = WebxdcHostView(session: session, hostWidgetKey: hostKey);

      expect(view.session, same(session));
      expect(view.hostWidgetKey, same(hostKey));

      await session.dispose();
    });
  });

  group('WebxdcSession.dispose', () {
    test('rejects further operations after dispose', () async {
      final bytes = _buildXdcZip(indexHtml: '<html></html>');
      final session = await WebxdcSession.open(
        xdcBytes: bytes,
        instanceId: 'gone',
        selfAddr: 'me',
        selfName: 'Me',
      );
      await session.dispose();

      expect(() => session.sendUpdate({'payload': 1}), throwsStateError);
    });
  });
}
