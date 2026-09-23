# flutter_webxdc_web

Flutter Web implementation of the [`flutter_webxdc`](../README.md)
`WebxdcPlatform` contract.

`WebWebxdcPlatform` is registered automatically by Flutter's Web plugin
registrant when the root `flutter_webxdc` package is used on the Web. It:

- creates one sandboxed `srcdoc` `<iframe>` per loaded app;
- converts archive assets to `data:` URLs and rewrites quoted relative
  `src`/`href` asset references in `index.html`;
- injects the messenger-owned `window.webxdc` shim (`sendUpdate`,
  `setUpdateListener`, `sendToChat`, `importFiles`, `selfAddr`, `selfName`);
- validates JSON `postMessage` traffic by both iframe source and a random
  per-instance token; and
- applies an iframe CSP that blocks network access unless the manifest sets
  `request_internet_access = true`.

After opening a `WebxdcSession`, a Flutter Web host attaches the iframe to its
chosen DOM element:

```dart
import 'dart:html' as html;

import 'package:flutter_webxdc/flutter_webxdc.dart';
import 'package:flutter_webxdc_web/flutter_webxdc_web.dart';

final session = await WebxdcSession.open(/* ... */);
final webPlatform = WebxdcPlatform.instance as WebWebxdcPlatform;
webPlatform.attachToElement(session.instanceId, html.document.querySelector('#app')!);
```

## Limitations

This is an initial browser host, not a completed WebXDC renderer. It rewrites
common quoted HTML `src`/`href` links only; CSS `url(...)`, dynamic imports,
and service-worker asset resolution are not yet virtualized. `sendToChat` from
iframe JS currently forwards text payloads; file payload forwarding remains
for follow-up work. The DOM layer temporarily uses the SDK's `dart:html`
compatibility API for `MessageEvent`/file-picker support; migration to the
`package:web` dependency already included in this package is tracked with the
remaining Web hardening work. See [`doc/design.md`](../doc/design.md) for the
security boundary and roadmap.
