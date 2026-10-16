import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../domain/bilibili_id.dart';

abstract interface class ExternalLinkService {
  Future<bool> open(Uri uri);
}

class SystemExternalLinkService implements ExternalLinkService {
  const SystemExternalLinkService();

  @override
  Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    // Android 12+ hands an https link only to an app verified for its domain,
    // and the Bilibili app is not, so its web links land in the browser. Its
    // own scheme reaches the app; without the app that launch fails and the
    // web link opens as before. Desktop has no app to try.
    final app = Platform.isAndroid || Platform.isIOS
        ? bilibiliAppLink(uri)
        : null;
    if (app != null && await _launch(app)) return true;
    return _launch(uri);
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

/// The Bilibili app's own link for a video, dynamic or space page, or null
/// for anything else.
///
/// Derived only from the exact web shapes this app builds, with the id checked
/// again, so no other https link gains an app-scheme route.
Uri? bilibiliAppLink(Uri web) {
  if (web.scheme != 'https' || web.hasQuery || web.hasFragment) return null;
  final path = web.pathSegments.where((s) => s.isNotEmpty).toList();
  switch (web.host) {
    case 'www.bilibili.com' || 'm.bilibili.com' || 'bilibili.com'
        when path.length == 2 && path[0] == 'video' && validBvid(path[1]):
      return Uri.parse('bilibili://video/${path[1]}');
    case 't.bilibili.com'
        when path.length == 1 && RegExp(r'^[1-9]\d{0,19}$').hasMatch(path[0]):
      return Uri.parse('bilibili://following/detail/${path[0]}');
    case 'space.bilibili.com'
        when path.length == 1 && validBilibiliMid(path[0]):
      return Uri.parse('bilibili://space/${path[0]}');
  }
  return null;
}
