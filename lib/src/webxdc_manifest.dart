import 'package:toml/toml.dart';

/// Parsed representation of a `.xdc` app's `manifest.toml`.
///
/// See `doc/design.md` §2.2 for the full schema documentation, defaults, and
/// the caveat about `minApiVersion`/`maxApiVersion` being a plugin-level
/// extension rather than a confirmed upstream spec field.
class WebxdcManifest {
  const WebxdcManifest({
    required this.name,
    this.sourceCodeUrl,
    this.requestInternetAccess = false,
    this.minApiVersion,
    this.maxApiVersion,
  });

  /// Required. Display name of the mini app, shown next to its icon.
  final String name;

  /// Optional. URL to the app's source code, surfaced by hosts as a
  /// "view source" link.
  final String? sourceCodeUrl;

  /// Optional, defaults to `false`. Whether the app may perform outgoing
  /// network requests from its web view/iframe.
  final bool requestInternetAccess;

  /// Optional. Lowest platform-interface API version required by the app.
  final int? minApiVersion;

  /// Optional. Highest platform-interface API version the app was tested
  /// against.
  final int? maxApiVersion;

  /// Parses a `manifest.toml` document already decoded into a `Map` (e.g.
  /// via `TomlDocument.parse(source).toMap()`), tolerating missing optional
  /// fields per doc/design.md §2.2.
  ///
  /// Throws a [FormatException] if `name` is missing or not a non-empty
  /// string, or if a present optional field has the wrong type.
  factory WebxdcManifest.fromMap(Map<String, dynamic> toml) {
    final name = toml['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException(
        'manifest.toml: `name` is required and must be a non-empty string',
      );
    }

    final sourceCodeUrl = toml['source_code_url'];
    if (sourceCodeUrl != null && sourceCodeUrl is! String) {
      throw const FormatException(
        'manifest.toml: `source_code_url` must be a string if present',
      );
    }

    final requestInternetAccess = toml['request_internet_access'];
    if (requestInternetAccess != null && requestInternetAccess is! bool) {
      throw const FormatException(
        'manifest.toml: `request_internet_access` must be a boolean if '
        'present',
      );
    }

    final minApiVersion = toml['min_api_version'];
    if (minApiVersion != null && minApiVersion is! int) {
      throw const FormatException(
        'manifest.toml: `min_api_version` must be an integer if present',
      );
    }

    final maxApiVersion = toml['max_api_version'];
    if (maxApiVersion != null && maxApiVersion is! int) {
      throw const FormatException(
        'manifest.toml: `max_api_version` must be an integer if present',
      );
    }

    return WebxdcManifest(
      name: name,
      sourceCodeUrl: sourceCodeUrl as String?,
      requestInternetAccess: (requestInternetAccess as bool?) ?? false,
      minApiVersion: minApiVersion as int?,
      maxApiVersion: maxApiVersion as int?,
    );
  }

  /// Parses a `manifest.toml` document from its raw TOML source text.
  factory WebxdcManifest.fromToml(String source) {
    final Map<String, dynamic> map;
    try {
      map = TomlDocument.parse(source).toMap();
    } on Exception catch (e) {
      throw FormatException('manifest.toml: invalid TOML: $e');
    }
    return WebxdcManifest.fromMap(map);
  }

  @override
  String toString() =>
      'WebxdcManifest(name: $name, sourceCodeUrl: $sourceCodeUrl, '
      'requestInternetAccess: $requestInternetAccess, '
      'minApiVersion: $minApiVersion, maxApiVersion: $maxApiVersion)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebxdcManifest &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          sourceCodeUrl == other.sourceCodeUrl &&
          requestInternetAccess == other.requestInternetAccess &&
          minApiVersion == other.minApiVersion &&
          maxApiVersion == other.maxApiVersion;

  @override
  int get hashCode => Object.hash(
    name,
    sourceCodeUrl,
    requestInternetAccess,
    minApiVersion,
    maxApiVersion,
  );
}
