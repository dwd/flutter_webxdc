import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';
import 'webview_webxdc_platform.dart';

/// Registers the [WebviewWebxdcPlatform] as the default instance for
/// [WebxdcPlatform].
class WebviewWebxdcPlugin {
  static void registerWith() {
    WebxdcPlatform.instance = WebviewWebxdcPlatform();
  }
}
