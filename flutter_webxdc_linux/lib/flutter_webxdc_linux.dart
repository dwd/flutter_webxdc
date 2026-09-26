/// Linux implementation of the `flutter_webxdc` platform contract.
///
/// See [LinuxWebxdcPlatform] for the rationale: it hosts `.xdc` assets
/// over a real loopback HTTP server and renders them in a real, embedded,
/// JS-bridged WebView using `flutter_inappwebview_forge` (a drop-in-API
/// -compatible fork of `flutter_inappwebview` with a native Linux/WPE
/// WebKit backend).
library;

export 'src/linux_webxdc_platform.dart';
export 'src/linux_webxdc_plugin.dart';
