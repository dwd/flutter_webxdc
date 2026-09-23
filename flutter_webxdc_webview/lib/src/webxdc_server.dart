import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// Backward-compatible alias for the shared [WebxdcLocalServer], which was
/// extracted into `flutter_webxdc_platform_interface` so it can be reused
/// by other native-adjacent implementations (e.g. `flutter_webxdc_linux`)
/// without duplicating the loopback HTTP host / CSP logic.
///
/// Keeping this alias (instead of just deleting this file) avoids breaking
/// existing imports of `package:flutter_webxdc_webview/src/webxdc_server.dart`.
typedef WebxdcServer = WebxdcLocalServer;
