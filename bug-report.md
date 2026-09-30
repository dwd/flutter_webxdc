# Bug report for `flutter_inappwebview_forge_linux` (tested at version 1.0.8)

This package is a Linux implementation forked from `flutter_inappwebview_linux`.
While trying to build [Wimsy](https://github.com/) (which depends on this
package transitively via `flutter_webxdc_linux`) against version `1.0.8`, we
ran into three separate, independent bugs, described below.

## 1. `linux/CMakeLists.txt` — stale `PLUGIN_NAME` from before the fork

Line 12:
```cmake
set(PLUGIN_NAME "flutter_inappwebview_linux_plugin")
```
This is left over from the original `flutter_inappwebview_linux` package. Since the package was renamed to `flutter_inappwebview_forge_linux`, Flutter's tooling generates `linux/flutter/generated_plugins.cmake` expecting a CMake target named after the *current* package name — `flutter_inappwebview_forge_linux_plugin` — via a `$<TARGET_FILE:flutter_inappwebview_forge_linux_plugin>` generator expression. Because the actual target is still named `flutter_inappwebview_linux_plugin`, CMake generation fails with:
```
No target "flutter_inappwebview_forge_linux_plugin"
```
Fix: change line 12 to
```cmake
set(PLUGIN_NAME "flutter_inappwebview_forge_linux_plugin")
```
Do **not** rename the actual source filenames (`flutter_inappwebview_linux_plugin.cc`, etc.) — only this target-name line needs to change.

## 2. `linux/include/flutter_inappwebview_linux/` — stale header directory name

The public header still lives under `include/flutter_inappwebview_linux/`, but Flutter's generated `generated_plugin_registrant.cc` (built from the current package name) includes it as:
```cpp
#include <flutter_inappwebview_forge_linux/flutter_inappwebview_linux_plugin.h>
```
Fix: rename the directory `linux/include/flutter_inappwebview_linux/` to `linux/include/flutter_inappwebview_forge_linux/` (and update the `#include` guards/paths inside the plugin's own `.cc`/`.h` files if they reference the old directory name internally).

## 3. `linux/in_app_webview/in_app_webview.cc` — calls to nonexistent WPE WebKit API + a variable-name typo

There are two call sites (one used for a "related/child webview" code path, one used for the "container" webview code path) that call:
```cpp
containerDataManager = webkit_website_data_manager_new(
    dataDirectory.value().c_str(), cacheDirectory.c_str());
if (containerDataManager != nullptr) {
  containerContext = webkit_web_context_new_with_website_data_manager(
      containerDataManager);
  ...
}
```
Neither `webkit_website_data_manager_new()` nor `webkit_web_context_new_with_website_data_manager()` exist as functions in current WPE WebKit — the data directory/cache directory and the data-manager-to-context association are GObject **construct-only properties**, not constructor functions. This causes a hard compile failure.

Fix: construct both via `g_object_new`:
```cpp
containerDataManager = WEBKIT_WEBSITE_DATA_MANAGER(g_object_new(
    WEBKIT_TYPE_WEBSITE_DATA_MANAGER,
    "base-data-directory", dataDirectory.value().c_str(),
    "base-cache-directory", cacheDirectory.c_str(),
    nullptr));
if (containerDataManager != nullptr) {
  containerContext = WEBKIT_WEB_CONTEXT(g_object_new(
      WEBKIT_TYPE_WEB_CONTEXT,
      "website-data-manager", containerDataManager,
      nullptr));
  ...
}
```
Apply this at **both** call sites (they have slightly different indentation, so a plain find/replace should target the logic, not exact whitespace).

Additionally, further down in the same file there's a variable declared as `contentBlockersChanged` but referenced elsewhere as `content_blockersChanged`:
```cpp
if (content_blockersChanged && content_blocker_handler_ != nullptr) {
```
This is a typo that fails to compile (undeclared identifier). Fix: change the usage to match the declaration, `contentBlockersChanged`.

---

Filed after investigating why `flutter build linux` failed for a downstream app (Wimsy) that pulls in `flutter_inappwebview_forge_linux` transitively via `flutter_webxdc_linux`.
