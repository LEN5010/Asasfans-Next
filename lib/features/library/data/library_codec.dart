import 'dart:convert';

import '../../../core/domain/content_identity.dart';
import '../../../core/storage/storage_failure.dart';
import '../../calendar/domain/calendar_event.dart';
import '../domain/library_models.dart';

abstract final class LibraryCodec {
  static const _invalid = StorageFailure(StorageFailureKind.invalidData);
  static String _text(Object? raw, [int max = 500000]) {
    if (raw is! String || raw.length > max || raw.contains('\u0000')) {
      throw _invalid;
    }
    return raw;
  }

  static String id(String value) {
    if (value.trim().isEmpty) throw _invalid;
    return _text(value, 256);
  }

  static Uri? publicUri(Object? raw) {
    final uri = raw is Uri
        ? raw
        : raw is String
        ? Uri.tryParse(raw)
        : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.toString().length > 4096) {
      return null;
    }
    const privateKeys = {
      'sessdata',
      'bili_jct',
      'cookie',
      'refresh_token',
      'access_token',
      'token',
      'auth_key',
      'sign',
      'signature',
      'expires',
      'deadline',
      'wstime',
      'wssecret',
      'authorization',
      'credential',
      'api_key',
      'apikey',
      'ossaccesskeyid',
      'security-token',
      'key-pair-id',
      'policy',
      'hdnts',
      'hdnea',
    };
    bool privateKey(String key) {
      final lower = key.toLowerCase();
      return privateKeys.contains(lower) ||
          [
            'x-amz-',
            'x-goog-',
            'x-oss-',
            'x-cos-',
            'q-sign-',
          ].any(lower.startsWith);
    }

    try {
      if (uri.queryParameters.keys.any(privateKey) ||
          (uri.fragment.contains('=') &&
              Uri.splitQueryString(uri.fragment).keys.any(privateKey))) {
        return null;
      }
      return uri;
    } on FormatException {
      return null;
    }
  }

  static String _encode(Map<String, Object?> fields) {
    final result = jsonEncode(fields);
    if (result.length > 1000000) throw _invalid;
    return result;
  }

  static List<String> _images(List<Uri> images) {
    if (images.length > 100) throw _invalid;
    return images
        .map(publicUri)
        .whereType<Uri>()
        .map((uri) => uri.toString())
        .toList();
  }

  static String encodeContent(ContentSnapshot item) => _encode({
    'v': 1,
    'source': item.identity.source.name,
    'id': id(item.identity.value),
    'title': _text(item.title, 1000),
    'body': _text(item.body),
    'authorName': _text(item.authorName, 1000),
    'authorId': _text(item.authorId, 256),
    'kind': item.kind.name,
    'images': _images(item.images),
  });
  static ContentSnapshot decodeContent(String json) {
    try {
      final raw = _object(json);
      final source = ContentSource.values.byName(_text(raw['source'], 64));
      final images = _strings(
        raw['images'],
        100,
        4096,
      ).map(publicUri).whereType<Uri>().toList();
      return ContentSnapshot(
        identity: ContentIdentity(
          source: source,
          value: id(_text(raw['id'], 256)),
        ),
        title: _text(raw['title'], 1000),
        body: _text(raw['body']),
        authorName: _text(raw['authorName'], 1000),
        authorId: _text(raw['authorId'], 256),
        kind: LibraryMediaKind.values.byName(_text(raw['kind'], 32)),
        images: List.unmodifiable(images),
      );
    } catch (_) {
      throw _invalid;
    }
  }

  static String encodeEvent(CalendarEvent event) {
    final encoded = _encode({
      'v': 1,
      'uid': id(event.uid),
      'recurrence': event.recurrenceId,
      'title': _text(event.title, 10000),
      'description': _text(event.description),
      'location': _text(event.location, 10000),
      'start': _eventTime(event.start, event.allDay),
      'end': _eventTime(event.end, event.allDay),
      'allDay': event.allDay,
      'status': event.status.name,
      'sequence': event.sequence,
      'categories': event.categories,
      'members': event.members,
      'url': publicUri(event.sourceUrl)?.toString(),
    });
    decodeEvent(encoded);
    return encoded;
  }

  static String _eventTime(DateTime value, bool allDay) =>
      (allDay
              ? DateTime.utc(value.year, value.month, value.day)
              : value.toUtc())
          .toIso8601String();
  static CalendarEvent decodeEvent(String json) {
    try {
      final raw = _object(json);
      final start = _instant(raw['start']);
      final end = _instant(raw['end']);
      if (raw['allDay'] is! bool ||
          raw['sequence'] is! int ||
          (raw['sequence'] as int) < 0 ||
          !end.isAfter(start)) {
        throw _invalid;
      }
      final allDay = raw['allDay'] as bool;
      if (allDay &&
          (start.hour != 0 ||
              start.minute != 0 ||
              start.second != 0 ||
              start.millisecond != 0 ||
              start.microsecond != 0 ||
              end.hour != 0 ||
              end.minute != 0 ||
              end.second != 0 ||
              end.millisecond != 0 ||
              end.microsecond != 0)) {
        throw _invalid;
      }
      return CalendarEvent(
        uid: id(_text(raw['uid'], 256)),
        recurrenceId: raw['recurrence'] == null
            ? null
            : id(_text(raw['recurrence'], 256)),
        title: _text(raw['title'], 10000),
        description: _text(raw['description']),
        location: _text(raw['location'], 10000),
        start: start,
        end: end,
        allDay: allDay,
        status: EventStatus.values.byName(_text(raw['status'], 32)),
        sequence: raw['sequence'] as int,
        categories: _strings(raw['categories'], 100, 1000),
        members: _strings(raw['members'], 100, 1000),
        sourceUrl: publicUri(raw['url']),
      );
    } catch (_) {
      throw _invalid;
    }
  }

  static DateTime _instant(Object? raw) {
    final text = _text(raw, 64);
    final time = DateTime.parse(text);
    if (!time.isUtc || time.toIso8601String() != text) throw _invalid;
    return time;
  }

  static Map<String, dynamic> _object(String text) {
    if (text.length > 1000000) throw _invalid;
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic> || raw['v'] != 1) throw _invalid;
    return raw;
  }

  static List<String> _strings(Object? raw, int count, int length) {
    if (raw is! List || raw.length > count) throw _invalid;
    return List.unmodifiable(raw.map((value) => _text(value, length)));
  }
}
