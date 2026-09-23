// Unit tests for the WebxdcPlatform contract itself: instance
// registration, and that unimplemented methods surface a clear
// UnimplementedError rather than failing silently, per doc/design.md §2.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// A minimal platform implementation used only to exercise the
/// [WebxdcPlatform] contract in tests; not a real platform package.
class _FakeWebxdcPlatform extends WebxdcPlatform {}

void main() {
  tearDown(WebxdcPlatform.resetInstanceForTesting);

  group('WebxdcPlatform.instance', () {
    test('throws StateError when no platform implementation is registered', () {
      WebxdcPlatform.resetInstanceForTesting();
      expect(() => WebxdcPlatform.instance, throwsStateError);
    });

    test('returns the registered instance', () {
      final fake = _FakeWebxdcPlatform();
      WebxdcPlatform.instance = fake;

      expect(WebxdcPlatform.instance, same(fake));
    });
  });

  group('WebxdcPlatform default method bodies', () {
    test('every method throws UnimplementedError by default', () async {
      final platform = _FakeWebxdcPlatform();

      await expectLater(
        () => platform.loadApp(
          instanceId: 'a',
          files: <String, Uint8List>{},
          selfAddr: 'me',
          selfName: 'Me',
        ),
        throwsUnimplementedError,
      );
      await expectLater(
        () => platform.deliverUpdateToApp(
          'a',
          const WebxdcUpdate(payload: 1, serial: 1, maxSerial: 1),
        ),
        throwsUnimplementedError,
      );
      await expectLater(
        () => platform.sendToChat(instanceId: 'a', text: 'hi'),
        throwsUnimplementedError,
      );
      await expectLater(
        () => platform.importFiles(instanceId: 'a'),
        throwsUnimplementedError,
      );
      await expectLater(
        () => platform.disposeApp('a'),
        throwsUnimplementedError,
      );
      expect(platform.supportsRealtimeChannel, isFalse);
    });

    test('event streams default to empty', () async {
      final platform = _FakeWebxdcPlatform();

      expect(await platform.sendUpdateEvents.isEmpty, isTrue);
      expect(await platform.sendToChatEvents.isEmpty, isTrue);
    });
  });
}
