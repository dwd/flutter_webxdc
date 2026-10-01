import 'package:flutter/widgets.dart';

/// Builds [builder]'s widget while watching for changes in the box this
/// widget is laid out in, invoking [onSizeChanged] whenever that box's size
/// actually changes (not on the first layout pass).
///
/// Used by native WebView-based [WebxdcPlatform] implementations (e.g.
/// `flutter_webxdc_webview`, `flutter_webxdc_linux`) to notice when the
/// embedding card/window around a hosted app is resized (for example when
/// it's maximized/restored) so they can forward that as a DOM `resize`
/// event into the app. Flutter lays out the native WebView widget to its
/// new size automatically, but the *hosted page inside it* is never told
/// its viewport changed unless something dispatches a DOM event for it —
/// many mini-apps size themselves (canvas dimensions, flex layouts, game
/// viewports) once at load time from `window.innerWidth`/`innerHeight` and
/// never re-measure afterwards. See doc/design.md §2/§6.
class WebxdcSizeObserver extends StatefulWidget {
  const WebxdcSizeObserver({
    super.key,
    required this.builder,
    required this.onSizeChanged,
  });

  final Widget Function() builder;
  final void Function(Size size) onSizeChanged;

  @override
  State<WebxdcSizeObserver> createState() => _WebxdcSizeObserverState();
}

class _WebxdcSizeObserverState extends State<WebxdcSizeObserver> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final lastSize = _lastSize;
        if (lastSize != null && lastSize != size) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onSizeChanged(size);
          });
        }
        _lastSize = size;
        return widget.builder();
      },
    );
  }
}
