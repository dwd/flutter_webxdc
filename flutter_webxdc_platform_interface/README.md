# flutter_webxdc_platform_interface

A common platform interface for the [`flutter_webxdc`](../README.md) plugin.

This package defines the stable Dart-side contract
(`WebxdcPlatform`, `WebxdcUpdate`, JS-bridge event types) that
per-platform implementation packages (`flutter_webxdc_memory`,
`flutter_webxdc_android`, `flutter_webxdc_web`, `flutter_webxdc_linux`,
`flutter_webxdc_macos`, `flutter_webxdc_windows`) must conform to, per the
federated package layout recorded in
[`doc/design.md`](../doc/design.md#2-target-federated-package-layout).

Users of the `flutter_webxdc` plugin should generally not need to depend on
this package directly — see the app-facing package instead — unless they are
implementing support for a new platform.

## Status

The first concrete implementation is
[`flutter_webxdc_memory`](../flutter_webxdc_memory/README.md)
(`MemoryWebxdcPlatform`). Native/Web platform packages are not implemented
yet. See [`doc/design.md`](../doc/design.md) for the target architecture and
[`CHANGELOG.md`](CHANGELOG.md) for what is implemented so far.
