import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

import 'linux_webxdc_platform.dart';

/// Registers the [LinuxWebxdcPlatform] as the default instance for
/// [WebxdcPlatform] on Linux.
class LinuxWebxdcPlugin {
  static void registerWith() {
    WebxdcPlatform.instance = LinuxWebxdcPlatform();
  }
}
