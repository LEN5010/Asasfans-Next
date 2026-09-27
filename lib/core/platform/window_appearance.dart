import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/preferences/domain/app_preferences.dart';

/// The native title bar of a macOS or Windows window is not drawn by
/// Flutter, so the app's light or dark choice never reaches it by itself.
/// This hands the choice to the window: light or dark as chosen, or back to
/// the system. Nothing else of the window changes (traffic lights or caption
/// buttons, dragging, full screen and restoration stay the system's).
abstract final class WindowAppearance {
  static const _channel = MethodChannel('asasfans.next/window_appearance');

  static Future<void> apply(AppAppearance appearance) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('set', appearance.name);
    } on MissingPluginException {
      // A host without the bridge (a test or preview window) keeps the
      // system title bar; the app itself is already themed.
    }
  }
}
