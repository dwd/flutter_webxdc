// Widget tests for [WebxdcSizeObserver], the shared resize-detection
// wrapper used by native WebView-based [WebxdcPlatform] implementations
// (`flutter_webxdc_webview`, `flutter_webxdc_linux`) to notice when the
// embedding card/window around a hosted app is resized, so they can
// forward that as a DOM `resize` event into the app (see doc/design.md
// §2/§6).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';

void main() {
  testWidgets("doesn't report a size on the very first layout pass", (
    tester,
  ) async {
    final reportedSizes = <Size>[];

    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: WebxdcSizeObserver(
            builder: () => const SizedBox.expand(),
            onSizeChanged: reportedSizes.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(reportedSizes, isEmpty);
  });

  testWidgets('reports the new size once the laid-out box actually changes', (
    tester,
  ) async {
    final reportedSizes = <Size>[];

    Widget host(double width, double height) => Center(
      child: SizedBox(
        width: width,
        height: height,
        child: WebxdcSizeObserver(
          builder: () => const SizedBox.expand(),
          onSizeChanged: reportedSizes.add,
        ),
      ),
    );

    await tester.pumpWidget(host(200, 100));
    await tester.pumpAndSettle();
    expect(reportedSizes, isEmpty);

    await tester.pumpWidget(host(320, 240));
    await tester.pumpAndSettle();

    expect(reportedSizes, [const Size(320, 240)]);
  });

  testWidgets("doesn't report anything when the box size stays the same", (
    tester,
  ) async {
    final reportedSizes = <Size>[];

    Widget host() => Center(
      child: SizedBox(
        width: 200,
        height: 100,
        child: WebxdcSizeObserver(
          builder: () => const SizedBox.expand(),
          onSizeChanged: reportedSizes.add,
        ),
      ),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(reportedSizes, isEmpty);
  });
}
