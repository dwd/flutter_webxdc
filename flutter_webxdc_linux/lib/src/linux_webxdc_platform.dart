import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webxdc_platform_interface/flutter_webxdc_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// Function used to open a URL in the system's default browser.
///
/// Matches [url_launcher.launchUrl]'s signature closely enough to be
/// injected in tests without depending on a real browser/desktop
/// environment being available.
typedef UrlOpener = Future<bool> Function(Uri url);

class _AppInstance {
  final WebxdcLocalServer server;
  final bool requestInternetAccess;
  final String selfAddr;
  final String selfName;
  final List<WebxdcUpdate> deliveredUpdates = <WebxdcUpdate>[];
  final List<WebxdcJsSendToChatEvent> sendToChatLog =
      <WebxdcJsSendToChatEvent>[];

  _AppInstance({
    required this.server,
    required this.requestInternetAccess,
    required this.selfAddr,
    required this.selfName,
  });

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/index.html');
}

/// Linux implementation of [WebxdcPlatform].
///
/// `flutter_inappwebview` (used by `flutter_webxdc_webview` for
/// Android/iOS/macOS/Windows) does not support Linux, and there is no
/// other maintained, embeddable in-app WebView plugin for Linux that this
/// repository can depend on today (see doc/design.md §2/§6). Rather than
/// leaving Linux entirely unimplemented, this platform still does real
/// work:
///
/// - It hosts the extracted `.xdc` file tree over a genuine loopback HTTP
///   server ([WebxdcLocalServer], shared with `flutter_webxdc_webview`),
///   enforcing the same `request_internet_access` Content-Security-Policy
///   contract as the native hosts.
/// - [buildHostWidget] returns an explicit widget (not a silent no-op
///   placeholder) that surfaces the served URL and lets the user open it
///   in their system browser via [UrlOpener].
///
/// Because the app runs in an external browser tab rather than an
/// embedded, JS-bridged surface, there is **no live `window.webxdc` JS
/// bridge**: `sendUpdate`/`setUpdateListener` calls made by a mini app
/// opened this way are not observed by this platform. [sendToChat] and
/// [importFiles] are available as host-driven operations (e.g. so a host
/// app's own chat/file UI can still call them programmatically), and are
/// recorded for inspection/testing exactly like `flutter_webxdc_memory`.
/// This limitation is intentional and documented in doc/design.md §6.
class LinuxWebxdcPlatform extends WebxdcPlatform {
  LinuxWebxdcPlatform({UrlOpener? urlOpener})
      : _urlOpener = urlOpener ?? url_launcher.launchUrl;

  static void registerWith() {
    WebxdcPlatform.instance = LinuxWebxdcPlatform();
  }

  final UrlOpener _urlOpener;
  final Map<String, _AppInstance> _apps = {};

  final StreamController<WebxdcJsSendUpdateEvent> _sendUpdateEvents =
      StreamController.broadcast();
  final StreamController<WebxdcJsSendToChatEvent> _sendToChatEvents =
      StreamController.broadcast();

  @override
  Stream<WebxdcJsSendUpdateEvent> get sendUpdateEvents =>
      _sendUpdateEvents.stream;

  @override
  Stream<WebxdcJsSendToChatEvent> get sendToChatEvents =>
      _sendToChatEvents.stream;

  @override
  Future<void> loadApp({
    required String instanceId,
    required Map<String, Uint8List> files,
    required String selfAddr,
    required String selfName,
    bool requestInternetAccess = false,
  }) async {
    if (_apps.containsKey(instanceId)) {
      throw StateError('Instance $instanceId is already loaded.');
    }
    if (!files.containsKey('index.html')) {
      throw ArgumentError.value(
        files.keys.toList(),
        'files',
        'must contain the mandatory index.html entry point',
      );
    }

    final server = WebxdcLocalServer(
      files,
      requestInternetAccess: requestInternetAccess,
    );
    await server.start();

    _apps[instanceId] = _AppInstance(
      server: server,
      requestInternetAccess: requestInternetAccess,
      selfAddr: selfAddr,
      selfName: selfName,
    );
  }

  @override
  Future<void> deliverUpdateToApp(
    String instanceId,
    WebxdcUpdate update,
  ) async {
    // No embedded/JS-bridged renderer exists for this instance, so there
    // is no `setUpdateListener` callback to forward the update to. It is
    // still recorded (see [deliveredUpdates]) so host apps and tests can
    // observe what *would* have been delivered.
    _requireApp(instanceId).deliveredUpdates.add(update);
  }

  @override
  Future<void> sendToChat({
    required String instanceId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
  }) async {
    _requireApp(instanceId);
    if (text == null && fileBytes == null) {
      throw ArgumentError(
        'sendToChat: at least one of text or fileBytes must be supplied',
      );
    }
    final event = WebxdcJsSendToChatEvent(
      instanceId: instanceId,
      text: text,
      fileBytes: fileBytes,
      fileName: fileName,
      contentType: contentType,
    );
    _requireApp(instanceId).sendToChatLog.add(event);
    _sendToChatEvents.add(event);
  }

  @override
  Future<List<WebxdcImportedFile>> importFiles({
    required String instanceId,
    List<String>? extensions,
    List<String>? mimeTypes,
    bool multiple = false,
  }) async {
    _requireApp(instanceId);
    // No native file-picker integration is wired up yet for this
    // fallback platform; host apps that need `importFiles` on Linux
    // should provide their own picker until a real one lands here.
    return const <WebxdcImportedFile>[];
  }

  @override
  Widget buildHostWidget(String instanceId, {Key? key}) {
    final app = _requireApp(instanceId);
    return _LinuxHostView(
      key: key,
      url: app.url,
      selfName: app.selfName,
      onOpenInBrowser: () => _urlOpener(app.url),
    );
  }

  @override
  Future<void> disposeApp(String instanceId) async {
    final app = _apps.remove(instanceId);
    if (app != null) {
      await app.server.stop();
    }
  }

  /// The URL the served app for [instanceId] is reachable at.
  ///
  /// Exposed so host apps can build their own custom UI around
  /// [buildHostWidget]'s default "open in browser" affordance if desired.
  Uri urlOf(String instanceId) => _requireApp(instanceId).url;

  /// Updates that would have been delivered to [instanceId]'s
  /// `setUpdateListener`, in delivery order. There is no live JS bridge
  /// on this platform, so this is a record for inspection/testing only.
  @visibleForTesting
  List<WebxdcUpdate> deliveredUpdates(String instanceId) =>
      List<WebxdcUpdate>.unmodifiable(_requireApp(instanceId).deliveredUpdates);

  @visibleForTesting
  List<WebxdcJsSendToChatEvent> sendToChatLog(String instanceId) =>
      List<WebxdcJsSendToChatEvent>.unmodifiable(
        _requireApp(instanceId).sendToChatLog,
      );

  _AppInstance _requireApp(String instanceId) {
    final app = _apps[instanceId];
    if (app == null) {
      throw StateError('Instance $instanceId is not loaded.');
    }
    return app;
  }
}

class _LinuxHostView extends StatelessWidget {
  const _LinuxHostView({
    super.key,
    required this.url,
    required this.selfName,
    required this.onOpenInBrowser,
  });

  final Uri url;
  final String selfName;
  final Future<bool> Function() onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        border: Border.all(color: const Color(0xFFB0BEC5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('flutter_webxdc_linux'),
              const SizedBox(height: 8),
              const Text(
                'No embeddable in-app WebView is available on Linux yet '
                '(flutter_inappwebview does not support Linux). This app '
                'is served locally and can be opened in your browser.',
              ),
              const SizedBox(height: 4),
              Text('Hosted for $selfName at $url'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onOpenInBrowser,
                child: const Text(
                  'Open in browser',
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
