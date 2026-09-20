import '../domain/bilibili_id.dart';

/// An in-memory secret value. Never put this object in logs, route arguments,
/// ordinary preferences, personal backups or public-source clients.
class BiliCredentials {
  BiliCredentials(Map<String, String> cookies, {this.refreshToken})
    : cookies = Map.unmodifiable(cookies) {
    if (cookies.keys.any((key) => !cookieNames.contains(key)) ||
        !cookies.containsKey('SESSDATA') ||
        !validBilibiliMid(cookies['DedeUserID'] ?? '') ||
        !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(cookies['bili_jct'] ?? '') ||
        cookies.values.any((value) => !_valid(value)) ||
        (refreshToken != null && !_valid(refreshToken!))) {
      throw const FormatException('Invalid Bilibili credentials');
    }
  }
  static const cookieNames = {
    'SESSDATA',
    'bili_jct',
    'DedeUserID',
    'DedeUserID__ckMd5',
    'sid',
  };
  final Map<String, String> cookies;
  final String? refreshToken;
  String get mid => cookies['DedeUserID']!;
  static bool _valid(String value) =>
      value.isNotEmpty &&
      value.length <= 4096 &&
      !RegExp(r'[\x00-\x20\x7f-\uffff;,"\\]').hasMatch(value);
  String? metadataHeader(Uri uri) =>
      uri.scheme == 'https' &&
          uri.host == 'api.bilibili.com' &&
          uri.port == 443 &&
          uri.userInfo.isEmpty
      ? [
          for (final key in cookieNames)
            if (cookies[key] != null) '$key=${cookies[key]}',
        ].join('; ')
      : null;
  @override
  String toString() => 'BiliCredentials(redacted)';
}
