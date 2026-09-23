# Repository working instructions

- Always commit completed work. Multiple commits for a single user instruction
  are fine; use coherent commits and include all changes made for that work.
  Leave unrelated user changes untouched.
- Give every commit a short, descriptive headline followed by a detailed body.
  The body must explain the code changes and their purpose, and describe testing:
  tests added or changed, commands run, results, and any verification limitations.
  Do not claim checks that were not performed.
- Always add useful tests for behavior changes. Cover expected behavior, failure
  cases, and relevant platform-channel or web-interop boundaries. Refactor
  existing code when needed to make behavior testable rather than leaving it
  untested. For changes limited to documentation or build configuration, use the
  relevant existing checks; add regression coverage when it would detect a
  meaningful failure.
- Run the relevant tests and build checks before committing. Use `flutter
  analyze` and `dart format --output=none --set-exit-if-changed .` for static
  checks, and `flutter test` for the unit/widget test suite. When platform
  channel or web-interop code changes, also verify the affected platform(s)
  build (`flutter build apk`, `flutter build linux`/`macos`/`windows`,
  `flutter build web`, as relevant) rather than assuming compatibility across
  targets.
- Maintain the overall design in `doc/design.md`, including decisions,
  assumptions, scope, test coverage, and known limitations. Keep `README.md`
  focused on usage, supported platforms, and externally relevant compatibility
  behavior.
- Stop and ask questions when requirements or consequential design choices need
  clarification. Record the resulting decisions in the design document. Proceed
  with routine implementation choices and work already authorized by the user.

## Project context

This project, `flutter_webxdc`, is a Flutter plugin/library implementing the
[webxdc](https://webxdc.org/docs/spec/index.html) specification for
interactive, embeddable mini apps (`.xdc` archives) exchanged over chat-like
transports. It exposes the `window.webxdc` JavaScript API surface and hosting
behavior (status updates, peer-to-peer state sync, sandboxed execution) to
Flutter host applications. The Dart package name is `flutter_webxdc`.

The library must be targetable to Android, Desktop (Linux, macOS, Windows), and
Web. Platform-specific hosting of `.xdc` content will likely differ
significantly (e.g. a WebView-based sandbox on Android/Desktop versus an
iframe/Service-Worker bridge on Web); prefer the federated-plugin pattern
(a platform-interface package plus per-platform implementations) once the
implementation grows beyond a single-file skeleton, rather than branching on
platform checks inside shared code. Keep the public Dart API
(`lib/flutter_webxdc.dart`) platform-agnostic.

The test suite should cover the shared Dart API contract with `flutter test`
and must not require a real device, emulator, or browser for the default run.
Platform-specific behavior (WebView bridging, Service Worker packaging, native
storage/networking for peer sync) should be covered by tests scoped to that
platform, and clearly marked as such. Document intentional deviations from the
webxdc specification in `doc/design.md`.
