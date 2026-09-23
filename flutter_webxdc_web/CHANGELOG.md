## 0.0.1 (In Development)

* Add the initial Flutter Web `WebxdcPlatform` implementation. It registers
  through Flutter's Web plugin registrant, creates sandboxed `srcdoc` iframes,
  injects a nonce-bound `window.webxdc` `postMessage` bridge, replays updates,
  forwards JS-originated updates/chat requests, and opens the browser file
  picker for `importFiles`.
* Add VM-runnable protocol/document-builder tests. Browser DOM behavior is
  additionally checked by the root package's `flutter build web` validation.
