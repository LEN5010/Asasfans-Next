import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../network/api_failure.dart';

/// Signature algorithm and public reference vector are documented in
/// bili-sdk/docs/misc/sign/wbi.md. Key URLs are never fetched or persisted.
class WbiKeys {
  WbiKeys._(this._mixin);
  final String _mixin;
  static const _permutation = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
  ];
  factory WbiKeys.fromUrls(String image, String sub) {
    String key(String value) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.pathSegments.isEmpty) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final name = uri.pathSegments.last.split('.').first;
      if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(name)) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      return name;
    }

    final raw = key(image) + key(sub);
    return WbiKeys._(_permutation.map((index) => raw[index]).join());
  }

  String sign(Map<String, String> parameters, DateTime now) {
    final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (seconds < 0 ||
        parameters.containsKey('w_rid') ||
        parameters.containsKey('wts')) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final values = {
      for (final entry in parameters.entries)
        entry.key: entry.value.replaceAll(RegExp(r"[!'()*]"), ''),
      'wts': '$seconds',
    };
    final query = encode(values);
    final signature = md5.convert(utf8.encode(query + _mixin)).toString();
    return '$query&w_rid=$signature';
  }

  static String encode(Map<String, String> values) {
    final names = values.keys.toList()..sort();
    return names
        .map((key) => '${_component(key)}=${_component(values[key]!)}')
        .join('&');
  }

  static String _component(String value) => Uri.encodeComponent(value)
      .replaceAll('!', '%21')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');
  @override
  String toString() => 'WbiKeys(redacted)';
}
