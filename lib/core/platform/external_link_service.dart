import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/bilibili_id.dart';

abstract interface class ExternalLinkService {
  Future<bool> open(Uri uri);
}

class SystemExternalLinkService implements ExternalLinkService {
  const SystemExternalLinkService();

  static const _bilibiliApp = MethodChannel('asasfans.next/bilibili_app');

  @override
  Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    // Android 12+ hands an https link only to an app verified for its domain,
    // and the Bilibili app is not, so its web links land in the browser. Its
    // own scheme reaches the app; without the app that launch fails and the
    // web link opens as before. Desktop has no app to try.
    if (Platform.isAndroid || Platform.isIOS) {
      final app = bilibiliAppLink(uri);
      if (app != null && await _launch(app)) return true;
      // A shape the scheme does not cover, or one the app's scheme does not
      // route: the web link itself, addressed to the Bilibili app by package,
      // which the domain check does not apply to.
      if (Platform.isAndroid && isBilibiliWeb(uri) && await _inBilibili(uri)) {
        return true;
      }
    }
    return _launch(uri);
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }

  static Future<bool> _inBilibili(Uri uri) async {
    try {
      return await _bilibiliApp.invokeMethod<bool>('open', {
            'url': uri.toString(),
          }) ??
          false;
    } on Exception {
      return false;
    }
  }
}

/// A page on Bilibili's own web domains or its short links.
bool isBilibiliWeb(Uri uri) {
  final host = uri.host.toLowerCase();
  return uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (host == 'bilibili.com' ||
          host.endsWith('.bilibili.com') ||
          host == 'b23.tv');
}

/// The Bilibili app's own link for a video, dynamic, live room, space or
/// search page, or null for anything else.
///
/// Built from the id in the path alone, checked again, so no other https
/// link gains an app-scheme route. Sharing and tracking parameters the
/// archive's links carry are dropped with the rest of the query; a video
/// with a part or a start time keeps its web link, which carries them.
Uri? bilibiliAppLink(Uri web) {
  if (web.scheme != 'https' || web.userInfo.isNotEmpty) return null;
  final host = web.host.toLowerCase();
  if (host == 'search.bilibili.com' &&
      web.path == '/all' &&
      web.queryParameters.length == 1 &&
      web.queryParameters['keyword']?.isNotEmpty == true) {
    return Uri.parse(
      'bilibili://search?keyword=${Uri.encodeComponent(web.queryParameters['keyword']!)}',
    );
  }
  final path = web.pathSegments.where((s) => s.isNotEmpty).toList();
  final id = RegExp(r'^[1-9]\d{0,19}$');
  bool numbered(int length, String? head) =>
      path.length == length &&
      (head == null || path[0] == head) &&
      id.hasMatch(path.last);
  switch (host) {
    case 'www.bilibili.com' || 'm.bilibili.com' || 'bilibili.com'
        when path.length == 2 &&
            path[0] == 'video' &&
            !web.queryParameters.containsKey('p') &&
            !web.queryParameters.containsKey('t'):
      if (validBvid(path[1])) return Uri.parse('bilibili://video/${path[1]}');
      final aid = RegExp(r'^av([1-9]\d{0,19})$').firstMatch(path[1]);
      return aid == null ? null : Uri.parse('bilibili://video/${aid[1]}');
    // t.bilibili.com/<id> now redirects to /opus/<id>: the same dynamic.
    case 'www.bilibili.com' || 'm.bilibili.com'
        when numbered(2, 'opus') ||
            (host == 'm.bilibili.com' && numbered(2, 'dynamic')):
      return Uri.parse('bilibili://following/detail/${path[1]}');
    case 't.bilibili.com' when numbered(1, null):
      return Uri.parse('bilibili://following/detail/${path[0]}');
    case 'live.bilibili.com' when numbered(1, null) || numbered(2, 'h5'):
      return Uri.parse('bilibili://live/${path.last}');
    // A space's tabs (/dynamic, /video) open the space itself.
    case 'space.bilibili.com' when path.isNotEmpty && validBilibiliMid(path[0]):
      return Uri.parse('bilibili://space/${path[0]}');
  }
  return null;
}
