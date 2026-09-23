// Unit tests for WebxdcController, the app-facing update log/replay API
// described in doc/design.md §4 (plugin vs. host boundary).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc/flutter_webxdc.dart';

void main() {
  group('WebxdcController.sendUpdate', () {
    test('assigns increasing serials starting at 1', () {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');

      final first = controller.sendUpdate({'payload': 1});
      final second = controller.sendUpdate({'payload': 2});

      expect(first.serial, 1);
      expect(second.serial, 2);
      expect(controller.maxSerial, 2);
    });

    test('falls back to `descr` for `info` when `info` is absent', () {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');

      final update = controller.sendUpdate({'payload': 1}, descr: 'legacy');

      expect(update.info, 'legacy');
    });

    test('prefers an explicit `info` over `descr`', () {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');

      final update = controller.sendUpdate({
        'payload': 1,
        'info': 'explicit',
      }, descr: 'legacy');

      expect(update.info, 'explicit');
    });

    test('is broadcast on the `updates` stream', () async {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');
      final received = <WebxdcUpdate>[];
      final sub = controller.updates.listen(received.add);

      controller.sendUpdate({'payload': 1});
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.payload, 1);
      await sub.cancel();
      await controller.dispose();
    });

    test(
      'throws WebxdcUpdateTooLargeException when exceeding sendUpdateMaxSize',
      () {
        final controller = WebxdcController(
          selfAddr: 'me',
          selfName: 'Me',
          sendUpdateMaxSize: 16,
        );

        expect(
          () => controller.sendUpdate({'payload': 'a much too long value'}),
          throwsA(isA<WebxdcUpdateTooLargeException>()),
        );
      },
    );
  });

  group('WebxdcController.deliverUpdate', () {
    test('shares the same serial sequence as sendUpdate', () {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');

      controller.sendUpdate({'payload': 'local'});
      final delivered = controller.deliverUpdate({'payload': 'remote'});

      expect(delivered.serial, 2);
      expect(controller.maxSerial, 2);
    });
  });

  group('WebxdcController.updatesSince', () {
    test('replays only updates with a greater serial, in order', () {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');

      controller.sendUpdate({'payload': 1});
      controller.sendUpdate({'payload': 2});
      controller.sendUpdate({'payload': 3});

      final replay = controller.updatesSince(1);

      expect(replay.map((u) => u.payload), [2, 3]);
    });

    test('defaults to the full backlog when serial is 0', () {
      final controller = WebxdcController(selfAddr: 'me', selfName: 'Me');

      controller.sendUpdate({'payload': 1});
      controller.sendUpdate({'payload': 2});

      expect(controller.updatesSince(0), hasLength(2));
    });
  });
}
