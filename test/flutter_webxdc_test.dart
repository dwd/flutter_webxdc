// Unit tests for the shared, platform-agnostic WebxdcManifest parser.
//
// See doc/design.md §2.2 for the schema this validates against.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc/flutter_webxdc.dart';

void main() {
  group('WebxdcManifest.fromToml', () {
    test('parses all documented fields', () {
      final manifest = WebxdcManifest.fromToml('''
        name = "Hello"
        source_code_url = "https://example.com/src"
        request_internet_access = true
        min_api_version = 1
        max_api_version = 2
      ''');

      expect(manifest.name, 'Hello');
      expect(manifest.sourceCodeUrl, 'https://example.com/src');
      expect(manifest.requestInternetAccess, isTrue);
      expect(manifest.minApiVersion, 1);
      expect(manifest.maxApiVersion, 2);
    });

    test('applies documented defaults when optional fields are absent', () {
      final manifest = WebxdcManifest.fromToml('name = "Minimal"');

      expect(manifest.name, 'Minimal');
      expect(manifest.sourceCodeUrl, isNull);
      expect(manifest.requestInternetAccess, isFalse);
      expect(manifest.minApiVersion, isNull);
      expect(manifest.maxApiVersion, isNull);
    });

    test('throws FormatException when `name` is missing', () {
      expect(
        () => WebxdcManifest.fromToml('source_code_url = "https://x"'),
        throwsFormatException,
      );
    });

    test('throws FormatException when `name` is empty', () {
      expect(() => WebxdcManifest.fromToml('name = ""'), throwsFormatException);
    });

    test('throws FormatException when `name` has the wrong type', () {
      expect(() => WebxdcManifest.fromToml('name = 42'), throwsFormatException);
    });

    test('throws FormatException when `request_internet_access` has the '
        'wrong type', () {
      expect(
        () => WebxdcManifest.fromToml('''
            name = "App"
            request_internet_access = "yes"
          '''),
        throwsFormatException,
      );
    });

    test(
      'throws FormatException when `min_api_version` has the wrong type',
      () {
        expect(
          () => WebxdcManifest.fromToml('''
          name = "App"
          min_api_version = "1"
        '''),
          throwsFormatException,
        );
      },
    );

    test('throws FormatException for malformed TOML', () {
      expect(() => WebxdcManifest.fromToml('name = ['), throwsFormatException);
    });

    test('equality and hashCode are value-based', () {
      const a = WebxdcManifest(name: 'App');
      const b = WebxdcManifest(name: 'App');
      const c = WebxdcManifest(name: 'Other');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
