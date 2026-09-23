import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// Non-browser placeholder exported when this package is imported on a VM or
/// native target. The actual implementation is selected on Flutter Web.
class WebWebxdcPlatform extends WebxdcPlatform {
  WebWebxdcPlatform();

  static void registerWith() {
    throw UnsupportedError(
      'flutter_webxdc_web can only register on a Flutter Web target.',
    );
  }

  /// Browser-only API that attaches the sandboxed iframe to a DOM element.
  void attachToElement(String instanceId, Object container) {
    throw UnsupportedError(
      'WebWebxdcPlatform.attachToElement is only available on Flutter Web.',
    );
  }

  /// Browser-only API returning the iframe DOM element as an opaque object.
  Object iframeFor(String instanceId) {
    throw UnsupportedError(
      'WebWebxdcPlatform.iframeFor is only available on Flutter Web.',
    );
  }
}

/// Flutter's generated web-plugin registrant invokes this class on browsers.
class FlutterWebxdcWebPlugin {
  static void registerWith(Object registrar) =>
      WebWebxdcPlatform.registerWith();
}
