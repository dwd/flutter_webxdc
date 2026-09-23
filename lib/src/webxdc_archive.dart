import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'webxdc_manifest.dart';

/// A read-only, in-memory view of an extracted `.xdc` zip archive.
///
/// Per doc/design.md §3, assets are verified against path traversal
/// ("zip-slip") before being exposed, and are exposed read-only — nothing in
/// this class writes to disk. Hosting platform packages are responsible for
/// actually materializing these bytes into a web view/iframe.
class WebxdcArchive {
  WebxdcArchive._(this.manifest, this._files);

  /// The parsed `manifest.toml`, or `null` if the archive did not contain
  /// one (tolerated; see doc/design.md §2.2 caveat and upstream format
  /// docs, which describe `manifest.toml` as optional with `index.html`
  /// mandatory).
  final WebxdcManifest? manifest;

  final Map<String, Uint8List> _files;

  /// All file paths contained in the archive, relative to its root.
  Iterable<String> get filePaths => _files.keys;

  /// Read-only view of every file in the archive (`path` → bytes).
  ///
  /// Suitable for passing straight to [WebxdcPlatform.loadApp].
  Map<String, Uint8List> get files =>
      Map<String, Uint8List>.unmodifiable(_files);

  /// Whether the mandatory `index.html` entry point is present.
  bool get hasIndexHtml => _files.containsKey('index.html');

  /// Returns the raw bytes of [path], or `null` if it is not present.
  Uint8List? readBytes(String path) => _files[path];

  /// Returns the UTF-8 decoded contents of [path], or `null` if not present.
  String? readString(String path) {
    final bytes = readBytes(path);
    return bytes == null ? null : utf8.decode(bytes);
  }

  /// Opens a `.xdc` zip archive from [bytes].
  ///
  /// Throws a [FormatException] if:
  /// - the archive is not a valid zip,
  /// - any entry's path attempts to escape the archive root ("zip-slip" /
  ///   path traversal), per doc/design.md §3,
  /// - `index.html` is missing (the one mandatory entry point), or
  /// - a present `manifest.toml` fails to parse per [WebxdcManifest.fromToml].
  factory WebxdcArchive.fromBytes(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Exception catch (e) {
      throw FormatException('.xdc archive: not a valid zip file: $e');
    }

    final files = <String, Uint8List>{};
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = _sanitizedEntryName(entry.name);
      files[name] = entry.content;
    }

    if (!files.containsKey('index.html')) {
      throw const FormatException(
        '.xdc archive: missing mandatory `index.html` entry point',
      );
    }

    WebxdcManifest? manifest;
    final manifestSource = files['manifest.toml'];
    if (manifestSource != null) {
      manifest = WebxdcManifest.fromToml(utf8.decode(manifestSource));
    }

    return WebxdcArchive._(manifest, files);
  }

  /// Validates a zip entry name against path traversal ("zip-slip") and
  /// returns it normalized (leading `./`/`/` stripped).
  ///
  /// Throws a [FormatException] for absolute paths, `..` segments, or
  /// Windows-style drive-letter/backslash paths that could escape the
  /// extraction root.
  static String _sanitizedEntryName(String rawName) {
    if (rawName.contains('\\')) {
      throw FormatException(
        '.xdc archive: entry uses backslash path separators: $rawName',
      );
    }
    var name = rawName;
    while (name.startsWith('/') || name.startsWith('./')) {
      name = name.startsWith('/') ? name.substring(1) : name.substring(2);
    }
    if (name.isEmpty ||
        name.startsWith('..') ||
        name.split('/').contains('..') ||
        // Rejects absolute Windows paths such as `C:/...`.
        RegExp(r'^[a-zA-Z]:').hasMatch(name)) {
      throw FormatException(
        '.xdc archive: entry escapes the archive root: $rawName',
      );
    }
    return name;
  }
}
