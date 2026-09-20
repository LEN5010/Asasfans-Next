import '../network/api_failure.dart';

/// Strict identity/shape decoding; optional public metrics remain unknown.
abstract final class BiliValue {
  static Never invalid() =>
      throw const ApiFailure(ApiFailureKind.invalidResponse);
  static Map<String, Object?> map(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) invalid();
    return Map<String, Object?>.from(raw);
  }

  static String text(Object? raw, {int limit = 100000, bool required = false}) {
    if (raw == null && !required) return '';
    if (raw is! String ||
        raw.length > limit ||
        raw.contains('\u0000') ||
        (required && raw.trim().isEmpty)) {
      invalid();
    }
    return raw;
  }

  static String id(Object? raw, {bool zero = false}) {
    final value = raw is String
        ? raw
        : raw is int
        ? '$raw'
        : '';
    if (zero && value == '0') return value;
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(value)) invalid();
    return value;
  }

  static String pairedId(
    Map<String, Object?> row,
    String name, {
    bool zero = false,
  }) {
    final string = row['${name}_str'];
    final value = id(string ?? row[name], zero: zero);
    if (string != null && row[name] is int && value != '${row[name]}') {
      invalid();
    }
    return value;
  }

  static int? count(Object? raw) {
    final value = raw is int
        ? raw
        : raw is String && RegExp(r'^\d+$').hasMatch(raw)
        ? int.tryParse(raw)
        : null;
    return value != null && value >= 0 ? value : null;
  }

  static int integer(Object? raw) => count(raw) ?? invalid();
  static DateTime? date(Object? raw) {
    final value = count(raw);
    return value == null || value == 0 || value > 253402300799
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  static Duration? duration(Object? raw) {
    final value = count(raw);
    return value != null && value > 0 && value <= 2147483647
        ? Duration(seconds: value)
        : null;
  }

  static Uri? image(Object? raw) {
    if (raw is! String || raw.length > 4096) return null;
    final uri = Uri.tryParse(raw.startsWith('//') ? 'https:$raw' : raw);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && ![80, 443].contains(uri.port))) {
      return null;
    }
    return uri.replace(scheme: 'https', port: 443);
  }
}
