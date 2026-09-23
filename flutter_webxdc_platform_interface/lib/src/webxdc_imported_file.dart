import 'dart:typed_data';

/// A file selected by the user via [WebxdcPlatform.importFiles], mirroring
/// the `File` objects returned by the JS `importFiles(filters)` API
/// documented in doc/design.md §2.1.
///
/// No filesystem path is exposed — only the file's bytes, matching the
/// spec's requirement that mini apps never get direct filesystem access.
class WebxdcImportedFile {
  const WebxdcImportedFile({
    required this.name,
    required this.bytes,
    this.contentType,
  });

  /// The file's display/base name, as shown to the mini app.
  final String name;

  /// The file's raw bytes.
  final Uint8List bytes;

  /// The file's MIME type, if known.
  final String? contentType;

  @override
  String toString() =>
      'WebxdcImportedFile(name: $name, bytes: ${bytes.length}, '
      'contentType: $contentType)';
}
