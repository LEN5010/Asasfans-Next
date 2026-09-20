import '../domain/bilibili_id.dart';
import '../network/api_failure.dart';
import 'bili_credentials.dart';
import 'bili_metadata_client.dart';

/// Destinations and credential scope are different allowlists. A CDN mirror
/// may be readable without being entitled to receive account cookies.
abstract final class BiliMediaPolicy {
  static const credentialDomains = {
    'bilivideo.com',
    'bilivideo.cn',
    'bilibili.com',
  };
  static const mediaDomains = {
    ...credentialDomains,
    'acgvideo.com',
    'hdslb.com',
    'akamaized.net',
  };
  static bool _host(String host, Set<String> domains) =>
      domains.any((domain) => host == domain || host.endsWith('.$domain'));
  static bool allowed(Uri uri) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      uri.toString().length <= 16384 &&
      _host(uri.host, mediaDomains);
  static Uri fromApi(Object? value) {
    if (value is! String || value.length > 16384) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    var uri = Uri.tryParse(value.startsWith('//') ? 'https:$value' : value);
    // Upgrade a known CDN's old HTTP spelling before any network operation.
    // Redirects are not upgraded: a downgrade is rejected by allowed().
    if (uri?.scheme == 'http' && uri!.port == 80) {
      uri = uri.replace(scheme: 'https', port: 443);
    }
    if (uri == null || !allowed(uri)) {
      throw const ApiFailure(
        ApiFailureKind.forbidden,
        code: 'UNTRUSTED_MEDIA_URL',
      );
    }
    return uri;
  }

  static Map<String, String> headers(
    Uri uri,
    String bvid,
    BiliCredentials? credentials, {
    String? range,
  }) {
    if (!allowed(uri) || !validBvid(bvid)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    return {
      'User-Agent': BiliMetadataClient.userAgent,
      'Referer': 'https://www.bilibili.com/video/$bvid',
      'Accept': 'video/mp4, audio/mp4, application/octet-stream',
      'Accept-Encoding': 'identity',
      'Range': ?range,
      if (credentials != null && _host(uri.host, credentialDomains))
        'Cookie': [
          for (final name in BiliCredentials.cookieNames)
            if (credentials.cookies[name] != null)
              '$name=${credentials.cookies[name]}',
        ].join('; '),
    };
  }
}
