/// Flutter Web implementation of the `flutter_webxdc` platform contract.
///
/// In a browser, [WebWebxdcPlatform] hosts each app in a sandboxed iframe and
/// injects a messenger-owned `window.webxdc` shim. On non-web targets this
/// library exposes an unsupported stub so depending on the federated package
/// remains analyzable under a normal VM test run.
library;

export 'src/webxdc_web_platform_stub.dart'
    if (dart.library.html) 'src/webxdc_web_platform.dart';
export 'src/webxdc_web_protocol.dart';
