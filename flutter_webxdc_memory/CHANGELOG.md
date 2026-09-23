## 0.0.1

* Initial in-memory `WebxdcPlatform` implementation
  (`MemoryWebxdcPlatform`): `loadApp` / `deliverUpdateToApp` /
  `sendToChat` / `importFiles` / `disposeApp`, plus JS-originated
  `sendUpdateEvents` / `sendToChatEvents` streams and a
  `simulateJsSendUpdate` helper for tests. Registers via
  `MemoryWebxdcPlatform.registerWith()`.
