/// Linux implementation of the `flutter_webxdc` platform contract.
///
/// See [LinuxWebxdcPlatform] for the rationale: `flutter_inappwebview`
/// does not support Linux, so this package hosts `.xdc` assets over a
/// real loopback HTTP server and exposes an explicit "open in browser"
/// affordance instead of an embedded, JS-bridged WebView.
library;

export 'src/linux_webxdc_platform.dart';
export 'src/linux_webxdc_plugin.dart';
