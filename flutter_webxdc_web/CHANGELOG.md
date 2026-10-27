## 0.0.1 (In Development)

* Add the initial Flutter Web `WebxdcPlatform` implementation. It registers
  through Flutter's Web plugin registrant, creates sandboxed `srcdoc` iframes,
  injects a nonce-bound `window.webxdc` `postMessage` bridge, replays updates,
  forwards JS-originated updates/chat requests, and opens the browser file
  picker for `importFiles`.
* Add VM-runnable protocol/document-builder tests. Browser DOM behavior is
  additionally checked by the root package's `flutter build web` validation.
* Fix: `WebxdcWebDocumentBuilder` now neutralizes an app's conventional
  `<script src="webxdc.js">` reference (with or without a leading `/` or
  `./`) instead of leaving it untouched. Previously that tag resolved
  against the real hosting page's origin and tried to fetch over the
  network, which the injected CSP correctly blocked - surfacing as the app
  silently failing to load instead of using the already-injected inline
  `window.webxdc` shim.
