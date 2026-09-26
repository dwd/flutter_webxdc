// Widget-construction test for [LinuxWebxdcPlatform.buildHostWidget].
//
// This exercises the shared render contract (`buildHostWidget`/
// `buildWebView` construct without throwing, and updates delivered before
// a WebView controller exists are queued) rather than a real native
// rendering pass: plain `flutter test` never sets
// `InAppWebViewPlatform.instance` (there is no real native WPE WebKit
// engine in this sandbox), so asserting on rendered WebView pixels/DOM is
// out of scope here — see
// `flutter_webxdc_webview/test/webview_webxdc_platform_test.dart` for the
// equivalent pattern on the sibling native package. Kept as plain
// `test()`s rather than `testWidgets()` (matching that sibling file) so
// the real loopback [WebxdcLocalServer] started by [loadApp] doesn't have
// its `Timer` intercepted by `TestWidgetsFlutterBinding`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_forge_platform_interface/flutter_inappwebview_forge_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_linux/flutter_webxdc_linux.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

/// Minimal fake so constructing a real [InAppWebView] doesn't require a
/// real native WPE WebKit engine to be registered (which only happens via
/// the generated plugin registrant at app startup, not under plain
/// `flutter test`). Extending [InAppWebViewPlatform] (rather than
/// `implements`) is enough to satisfy its internal
/// `PlatformInterface.verify` token check.
class _FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) =>
      _FakeInAppWebViewWidget(params);
}

class _FakeInAppWebViewWidget extends PlatformInAppWebViewWidget {
  _FakeInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params)
      : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      controller as T;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();

  group('LinuxWebxdcPlatform.buildHostWidget', () {
    test('loadApp starts the server and buildHostWidget returns a widget',
        () async {
      final platform = LinuxWebxdcPlatform();
      const instanceId = 'instance-1';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList(utf8.encode('<html></html>')),
        },
        selfAddr: 'me@local',
        selfName: 'Alice',
      );

      expect(platform.buildHostWidget(instanceId), isNotNull);
      expect(platform.buildWebView(instanceId), isA<Widget>());

      await platform.disposeApp(instanceId);
    });

    test('deliverUpdateToApp queues updates until the WebView exists',
        () async {
      final platform = LinuxWebxdcPlatform();
      const instanceId = 'queued-update';
      await platform.loadApp(
        instanceId: instanceId,
        files: {
          'index.html': Uint8List.fromList(utf8.encode('<html></html>')),
        },
        selfAddr: 'me@local',
        selfName: 'Alice',
      );

      await platform.deliverUpdateToApp(
        instanceId,
        const WebxdcUpdate(payload: {'counter': 1}, serial: 1, maxSerial: 1),
      );

      expect(platform.pendingUpdateCount(instanceId), 1);
      await platform.disposeApp(instanceId);
    });
  });
}
