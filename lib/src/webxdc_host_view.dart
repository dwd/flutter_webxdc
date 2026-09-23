import 'package:flutter/widgets.dart';

import 'webxdc_session.dart';

/// Convenience widget that renders a [WebxdcSession]'s hosted app surface.
///
/// This is a thin declarative wrapper around [WebxdcSession.buildHostWidget].
class WebxdcHostView extends StatelessWidget {
  const WebxdcHostView({super.key, required this.session, this.hostWidgetKey});

  final WebxdcSession session;
  final Key? hostWidgetKey;

  @override
  Widget build(BuildContext context) {
    return session.buildHostWidget(key: hostWidgetKey);
  }
}
