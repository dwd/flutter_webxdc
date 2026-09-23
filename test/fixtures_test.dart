// Sanity test for the hand-written WebXDC fixtures under test/fixtures/.
//
// This does not exercise any platform/bridge implementation code (none
// exists yet, see doc/design.md). It only verifies that each fixture's
// manifest.toml is well-formed and matches the `manifest.toml` schema
// documented in doc/design.md §2.2, so the design's manifest contract has
// an executable check even before the real parser is implemented.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toml/toml.dart';

void main() {
  // `flutter test` runs with the package root as the working directory, so
  // fixtures can be located with a plain relative path.
  const fixturesDir = 'test/fixtures';

  group('basic_update fixture', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      final file = File('$fixturesDir/basic_update/manifest.toml');
      manifest = TomlDocument.parse(file.readAsStringSync()).toMap();
    });

    test('index.html and webxdc.js exist alongside the manifest', () {
      expect(File('$fixturesDir/basic_update/index.html').existsSync(), isTrue);
      expect(File('$fixturesDir/basic_update/webxdc.js').existsSync(), isTrue);
    });

    test('has a required string `name`', () {
      expect(manifest['name'], isA<String>());
      expect(manifest['name'], isNotEmpty);
    });

    test('declares optional fields with the documented types', () {
      expect(manifest['source_code_url'], isA<String>());
      expect(manifest['request_internet_access'], isA<bool>());
      expect(manifest['min_api_version'], isA<int>());
      expect(manifest['max_api_version'], isA<int>());
    });
  });

  group('manifest_variations fixture', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      final file = File('$fixturesDir/manifest_variations/manifest.toml');
      manifest = TomlDocument.parse(file.readAsStringSync()).toMap();
    });

    test('index.html exists alongside the manifest', () {
      expect(
        File('$fixturesDir/manifest_variations/index.html').existsSync(),
        isTrue,
      );
    });

    test('has a required string `name`', () {
      expect(manifest['name'], isA<String>());
      expect(manifest['name'], isNotEmpty);
    });

    test(
      'tolerates all optional fields being absent, per doc/design.md §2.2',
      () {
        expect(manifest.containsKey('source_code_url'), isFalse);
        expect(manifest.containsKey('request_internet_access'), isFalse);
        expect(manifest.containsKey('min_api_version'), isFalse);
        expect(manifest.containsKey('max_api_version'), isFalse);
      },
    );
  });
}
