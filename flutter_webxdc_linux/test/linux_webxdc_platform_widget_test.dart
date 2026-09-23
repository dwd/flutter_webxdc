// Widget test for [LinuxWebxdcPlatform.buildHostWidget].
//
// Kept in its own file (see linux_webxdc_platform_test.dart's header
// comment): the real loopback [WebxdcLocalServer] started by [loadApp]
// must run inside `tester.runAsync` here, since `TestWidgetsFlutterBinding`
// otherwise intercepts the real `Timer` it creates.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_linux/flutter_webxdc_linux.dart';

void main() {
  testWidgets('renders the served URL and opens it via the injected opener', (
    tester,
  ) async {
    Uri? openedUrl;
    final platform = LinuxWebxdcPlatform(
      urlOpener: (url) async {
        openedUrl = url;
        return true;
      },
    );

    await tester.runAsync(() async {
      await platform.loadApp(
        instanceId: 'instance-1',
        files: {
          'index.html': Uint8List.fromList(utf8.encode('<html></html>')),
        },
        selfAddr: 'me@local',
        selfName: 'Alice',
      );
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: platform.buildHostWidget('instance-1'),
      ),
    );

    expect(find.textContaining('flutter_webxdc_linux'), findsOneWidget);
    expect(find.textContaining('Alice'), findsOneWidget);
    expect(find.text('Open in browser'), findsOneWidget);

    await tester.tap(find.text('Open in browser'));
    await tester.pumpAndSettle();

    expect(openedUrl, platform.urlOf('instance-1'));

    await tester.runAsync(() => platform.disposeApp('instance-1'));
  });
}
