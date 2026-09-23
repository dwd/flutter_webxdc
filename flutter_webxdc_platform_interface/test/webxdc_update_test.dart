// Unit tests for the shared WebxdcUpdate JS-bridge payload model.
//
// See doc/design.md §2.1 for the `sendUpdate`/`setUpdateListener` contract
// this mirrors.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

void main() {
  group('WebxdcUpdate.fromJson', () {
    test('parses a minimal update with only `payload`', () {
      final update = WebxdcUpdate.fromJson(
        {'payload': 'hello'},
        serial: 1,
        maxSerial: 1,
      );

      expect(update.payload, 'hello');
      expect(update.serial, 1);
      expect(update.maxSerial, 1);
      expect(update.info, isNull);
      expect(update.notify, isNull);
    });

    test('parses all optional fields', () {
      final update = WebxdcUpdate.fromJson(
        {
          'payload': {'count': 1},
          'info': 'status',
          'document': 'doc.txt',
          'summary': 'summary text',
          'href': '#/page',
          'notify': {'alice': 'ping', '*': 'catch-all'},
        },
        serial: 3,
        maxSerial: 5,
      );

      expect(update.payload, {'count': 1});
      expect(update.info, 'status');
      expect(update.document, 'doc.txt');
      expect(update.summary, 'summary text');
      expect(update.href, '#/page');
      expect(update.notify, {'alice': 'ping', '*': 'catch-all'});
      expect(update.serial, 3);
      expect(update.maxSerial, 5);
    });

    test('throws FormatException when `payload` is missing', () {
      expect(
        () => WebxdcUpdate.fromJson({'info': 'x'}, serial: 1, maxSerial: 1),
        throwsFormatException,
      );
    });

    test('throws FormatException when `notify` is not a map', () {
      expect(
        () => WebxdcUpdate.fromJson(
          {'payload': 1, 'notify': 'oops'},
          serial: 1,
          maxSerial: 1,
        ),
        throwsFormatException,
      );
    });
  });

  group('WebxdcUpdate.toJson', () {
    test('round-trips through toJson/fromJson', () {
      const update = WebxdcUpdate(
        payload: {'a': 1},
        serial: 7,
        maxSerial: 9,
        info: 'info',
        notify: {'*': 'n'},
      );

      final json = update.toJson();
      final parsed = WebxdcUpdate.fromJson(
        json,
        serial: json['serial']! as int,
        maxSerial: json['max_serial']! as int,
      );

      expect(parsed.payload, update.payload);
      expect(parsed.serial, update.serial);
      expect(parsed.maxSerial, update.maxSerial);
      expect(parsed.info, update.info);
      expect(parsed.notify, update.notify);
    });

    test('omits absent optional fields', () {
      const update = WebxdcUpdate(payload: 'x', serial: 1, maxSerial: 1);
      final json = update.toJson();

      expect(json.containsKey('info'), isFalse);
      expect(json.containsKey('document'), isFalse);
      expect(json.containsKey('summary'), isFalse);
      expect(json.containsKey('href'), isFalse);
      expect(json.containsKey('notify'), isFalse);
    });
  });

  test('copyWith overrides only the given fields', () {
    const update = WebxdcUpdate(payload: 'x', serial: 1, maxSerial: 1);
    final updated = update.copyWith(serial: 2, maxSerial: 5);

    expect(updated.payload, 'x');
    expect(updated.serial, 2);
    expect(updated.maxSerial, 5);
  });
}
