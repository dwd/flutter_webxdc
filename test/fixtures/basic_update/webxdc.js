// Stub `window.webxdc` shim used ONLY by this fixture for local, in-repo
// testing/reasoning about the basic_update scenario described in
// doc/design.md §2.1 ("JS API contract"). This file is NOT shipped as part
// of the flutter_webxdc plugin: in the real architecture, an equivalent
// shim is injected by the host platform package (flutter_webxdc_android,
// flutter_webxdc_web, ...), never bundled inside a `.xdc` file.
//
// It implements just enough of the documented contract (sendUpdate /
// setUpdateListener) to let a browser or WebView load index.html standalone
// and see the round-trip work, in-memory, within a single instance.
(function () {
  let listener = null;
  let lastSerial = 0;
  const backlog = [];

  window.webxdc = {
    selfAddr: 'fixture@local',
    selfName: 'Fixture User',
    sendUpdateInterval: 10000,
    sendUpdateMaxSize: 128000,

    setUpdateListener(callback, serial) {
      listener = callback;
      const since = serial || 0;
      backlog
        .filter((update) => update.serial > since)
        .forEach((update) => listener(update));
      return Promise.resolve();
    },

    sendUpdate(update, descr) {
      lastSerial += 1;
      const delivered = Object.assign({}, update, {
        serial: lastSerial,
        maxSerial: lastSerial,
      });
      backlog.push(delivered);
      if (listener) {
        listener(delivered);
      }
      return Promise.resolve();
    },
  };
})();
