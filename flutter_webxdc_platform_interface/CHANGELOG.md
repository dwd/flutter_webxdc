## 0.0.1

* Added JS→host event types (`WebxdcJsSendUpdateEvent`,
  `WebxdcJsSendToChatEvent`) and default empty
  `sendUpdateEvents` / `sendToChatEvents` streams on `WebxdcPlatform`, so
  platform implementations have a uniform way to surface mini-app JS calls
  to the host / `WebxdcSession`.
* Initial scaffolding: `WebxdcUpdate` (moved from `flutter_webxdc`),
  `WebxdcImportedFile`, and the abstract `WebxdcPlatform` contract (built on
  `package:plugin_platform_interface`, `PlatformInterface` + static
  `instance` pattern). Every method defaults to `UnimplementedError`.
