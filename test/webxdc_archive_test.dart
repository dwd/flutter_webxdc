// Unit tests for WebxdcArchive, the read-only `.xdc` zip container reader.
//
// See doc/design.md §3 (sandboxing/security requirements) for the
// zip-slip/path-traversal protection this exercises.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc/flutter_webxdc.dart';

Uint8List _buildZip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  final encoded = ZipEncoder().encodeBytes(archive);
  return Uint8List.fromList(encoded);
}

void main() {
  group('WebxdcArchive.fromBytes', () {
    test('reads index.html and manifest.toml when both are present', () {
      final zip = _buildZip({
        'index.html': '<html></html>',
        'manifest.toml': 'name = "Hello"',
      });

      final archive = WebxdcArchive.fromBytes(zip);

      expect(archive.hasIndexHtml, isTrue);
      expect(archive.readString('index.html'), '<html></html>');
      expect(archive.manifest, isNotNull);
      expect(archive.manifest!.name, 'Hello');
    });

    test('tolerates a missing manifest.toml, per doc/design.md §2.2', () {
      final zip = _buildZip({'index.html': '<html></html>'});

      final archive = WebxdcArchive.fromBytes(zip);

      expect(archive.hasIndexHtml, isTrue);
      expect(archive.manifest, isNull);
    });

    test('throws FormatException when index.html is missing', () {
      final zip = _buildZip({'manifest.toml': 'name = "Hello"'});

      expect(() => WebxdcArchive.fromBytes(zip), throwsFormatException);
    });

    test('throws FormatException when manifest.toml is malformed', () {
      final zip = _buildZip({
        'index.html': '<html></html>',
        'manifest.toml': 'name = [',
      });

      expect(() => WebxdcArchive.fromBytes(zip), throwsFormatException);
    });

    test('throws FormatException for a zip-slip entry with `..` segments', () {
      final zip = _buildZip({
        'index.html': '<html></html>',
        '../../etc/passwd': 'evil',
      });

      expect(() => WebxdcArchive.fromBytes(zip), throwsFormatException);
    });

    test('normalizes a leading-slash entry into a safe relative path', () {
      // A leading `/` alone does not escape the archive root once stripped,
      // so it is normalized rather than rejected; only `..` segments (or
      // backslash/drive-letter paths) are treated as zip-slip attempts.
      final zip = _buildZip({
        'index.html': '<html></html>',
        '/notes.txt': 'not evil',
      });

      final archive = WebxdcArchive.fromBytes(zip);

      expect(archive.filePaths, contains('notes.txt'));
    });

    test('throws FormatException for bytes that are not a valid zip', () {
      final notAZip = Uint8List.fromList(utf8.encode('not a zip file'));

      expect(() => WebxdcArchive.fromBytes(notAZip), throwsFormatException);
    });

    test('exposes all non-traversal file paths via filePaths', () {
      final zip = _buildZip({
        'index.html': '<html></html>',
        'assets/app.js': 'console.log(1);',
      });

      final archive = WebxdcArchive.fromBytes(zip);

      expect(archive.filePaths, containsAll(['index.html', 'assets/app.js']));
      expect(archive.readBytes('missing.txt'), isNull);
    });
  });
}
