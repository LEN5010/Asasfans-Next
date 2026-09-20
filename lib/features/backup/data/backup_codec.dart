import 'dart:convert';
import 'dart:typed_data';

import '../../../core/domain/content_identity.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../library/data/library_codec.dart';
import '../../library/domain/library_models.dart';
import '../../preferences/domain/app_preferences.dart';
import '../../rules/data/rules_codec.dart';
import '../domain/personal_backup.dart';

class ValidatedBackup implements BackupImport {
  ValidatedBackup._(this.summary, Map<String, List<Map<String, Object?>>> rows)
    : tables = Map.unmodifiable({
        for (final entry in rows.entries)
          entry.key: List<Map<String, Object?>>.unmodifiable(
            entry.value.map((row) => Map<String, Object?>.unmodifiable(row)),
          ),
      });
  @override
  final BackupSummary summary;
  final Map<String, List<Map<String, Object?>>> tables;
}

/// Portable allowlisted v3 format; v1/v2 remain readable without read receipts.
/// Neither raw database files nor cache / credential stores are exportable.
abstract final class BackupCodec {
  /// Version written by [encode]. Older files stay readable; see [columns].
  static const formatVersion = 4;
  static const maxBytes = 32 * 1024 * 1024;
  static const maxRows = 50000;
  static const _invalid = BackupFailure(BackupFailureKind.invalid);
  static const columnsV1 = {
    'preferences': ['key', 'value'],
    'content_refs': ['source', 'content_id', 'snapshot', 'updated_at'],
    'collection_folders': ['id', 'name', 'created_at'],
    'collection_items': ['folder_id', 'source', 'content_id', 'added_at'],
    'watch_later': ['source', 'content_id', 'added_at', 'done'],
    'content_history': ['source', 'content_id', 'action', 'last_at', 'visits'],
    'local_subscriptions': ['mid', 'name', 'avatar', 'added_at'],
    'calendar_follows': [
      'source',
      'uid',
      'recurrence_id',
      'snapshot',
      'sequence',
      'followed_at',
      'observed_at',
    ],
  };
  static const columnsV2 = {
    ...columnsV1,
    'content_rules': [
      'id',
      'kind',
      'scope',
      'value',
      'enabled',
      'expires_at',
      'created_at',
      'updated_at',
    ],
    'rule_settings': ['key', 'value'],
  };
  static const columnsV3 = {
    ...columnsV2,
    'subscription_reads': ['bvid', 'is_read', 'updated_at'],
  };
  static const columns = {
    ...columnsV3,
    'playback_progress': [
      'source',
      'content_id',
      'part_id',
      'position_ms',
      'duration_ms',
      'completed',
      'updated_at',
    ],
    'playback_bookmarks': [
      'id',
      'source',
      'content_id',
      'part_id',
      'start_ms',
      'end_ms',
      'title',
      'note',
      'created_at',
      'updated_at',
    ],
  };
  static final preferenceKeys = {
    'appearance',
    for (final section in HomeSection.values) 'home.${section.name}.visible',
  };

  static Uint8List encode(
    Map<String, List<Map<String, Object?>>> tables,
    DateTime at,
  ) {
    // Canonicalize snapshots before exporting, including URL filtering. Do not
    // propagate future/unknown DTO properties that might contain media tokens.
    final data = <String, Object?>{};
    for (final entry in tables.entries) {
      data[entry.key] = [
        for (final row in entry.value)
          {
            ...row,
            if (entry.key == 'content_refs')
              'snapshot': jsonDecode(
                LibraryCodec.encodeContent(
                  LibraryCodec.decodeContent(row['snapshot'] as String),
                ),
              ),
            if (entry.key == 'calendar_follows')
              'snapshot': jsonDecode(
                LibraryCodec.encodeEvent(
                  LibraryCodec.decodeEvent(row['snapshot'] as String),
                ),
              ),
          },
      ];
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'asasfans.personal',
          'version': formatVersion,
          'exported_at': at.toUtc().toIso8601String(),
          'data': data,
        }),
      ),
    );
    decode(bytes); // An exported file must satisfy the same restore contract.
    return bytes;
  }

  static ValidatedBackup decode(Uint8List bytes) {
    try {
      if (bytes.length > maxBytes) {
        throw const BackupFailure(BackupFailureKind.tooLarge);
      }
      _depth(bytes);
      final root = _object(jsonDecode(utf8.decode(bytes)), [
        'format',
        'version',
        'exported_at',
        'data',
      ]);
      if (root['format'] != 'asasfans.personal') throw _invalid;
      if (root['version'] is! int ||
          !const [1, 2, 3, 4].contains(root['version'])) {
        throw const BackupFailure(BackupFailureKind.incompatible);
      }
      final atText = _text(root['exported_at'], 64);
      final at = DateTime.parse(atText);
      if (!at.isUtc || at.toIso8601String() != atText) throw _invalid;
      _time(at.millisecondsSinceEpoch);
      final fields = switch (root['version']) {
        1 => columnsV1,
        2 => columnsV2,
        3 => columnsV3,
        _ => columns,
      };
      final data = _object(root['data'], fields.keys.toList());
      final result = <String, List<Map<String, Object?>>>{};
      var total = 0;
      for (final entry in fields.entries) {
        final rows = data[entry.key];
        if (rows is! List) throw _invalid;
        total += rows.length;
        if (total > maxRows) {
          throw const BackupFailure(BackupFailureKind.tooLarge);
        }
        if (entry.key == 'content_rules' && rows.length > RulesCodec.maxRules) {
          throw const BackupFailure(BackupFailureKind.tooLarge);
        }
        result[entry.key] = rows
            .map((row) => _row(entry.key, _object(row, entry.value)))
            .toList();
      }
      result.putIfAbsent('content_rules', () => []);
      result.putIfAbsent('rule_settings', () => []);
      result.putIfAbsent('subscription_reads', () => []);
      result.putIfAbsent('playback_progress', () => []);
      result.putIfAbsent('playback_bookmarks', () => []);
      _relations(result);
      return ValidatedBackup._(
        BackupSummary(
          exportedAt: at,
          counts: {for (final e in result.entries) e.key: e.value.length},
        ),
        result,
      );
    } on BackupFailure {
      rethrow;
    } catch (_) {
      throw _invalid;
    }
  }

  static Map<String, Object?> _row(String table, Map<String, Object?> row) {
    for (final key in [
      'added_at',
      'updated_at',
      'created_at',
      'last_at',
      'followed_at',
      'observed_at',
    ]) {
      if (row.containsKey(key)) _time(row[key]);
    }
    if (table == 'subscription_reads') {
      if (!validBvid(_text(row['bvid'], 12)) ||
          (row['is_read'] != 0 && row['is_read'] != 1) ||
          row['is_read'] is! int) {
        throw _invalid;
      }
    } else if (table == 'content_rules') {
      RulesCodec.validateBackup(row);
    } else if (table == 'rule_settings') {
      if (row['key'] != 'subscribed_first' ||
          (row['value'] != 'true' && row['value'] != 'false')) {
        throw _invalid;
      }
    } else if (table == 'preferences') {
      final key = _text(row['key'], 64);
      if (!preferenceKeys.contains(key)) throw _invalid;
      final value = _text(row['value'], 32);
      if (key == 'appearance'
          ? !AppAppearance.values.any((e) => e.name == value)
          : value != 'true' && value != 'false') {
        throw _invalid;
      }
    } else if (table == 'collection_folders') {
      _id(row['id']);
      final name = _text(row['name'], 64);
      if (name.trim().isEmpty || name.trim() != name) throw _invalid;
    } else if (table == 'local_subscriptions') {
      if (!LocalSubscription.validMid(_text(row['mid'], 20))) throw _invalid;
      _text(row['name'], 1000);
      _uri(row['avatar'], nullable: true);
    } else if (table == 'calendar_follows') {
      _uri(row['source']);
      _id(row['uid']);
      final recurrence = _text(row['recurrence_id'], 256);
      if (recurrence.isNotEmpty) _id(recurrence);
      _number(row['sequence']);
      final snapshot = _object(row['snapshot'], [
        'v',
        'uid',
        'recurrence',
        'title',
        'description',
        'location',
        'start',
        'end',
        'allDay',
        'status',
        'sequence',
        'categories',
        'members',
        'url',
      ]);
      _uri(snapshot['url'], nullable: true);
      final event = LibraryCodec.decodeEvent(jsonEncode(snapshot));
      if (event.uid != row['uid'] ||
          (event.recurrenceId ?? '') != recurrence ||
          event.sequence != row['sequence']) {
        throw _invalid;
      }
      return {...row, 'snapshot': LibraryCodec.encodeEvent(event)};
    } else {
      final source = _text(row['source'], 64);
      if (!ContentSource.values.any((s) => s.name == source)) throw _invalid;
      _id(row['content_id']);
      if (table == 'content_refs') {
        final snapshot = _object(row['snapshot'], [
          'v',
          'source',
          'id',
          'title',
          'body',
          'authorName',
          'authorId',
          'kind',
          'images',
        ]);
        final images = snapshot['images'];
        if (images is! List) throw _invalid;
        for (final image in images) {
          _uri(image);
        }
        final item = LibraryCodec.decodeContent(jsonEncode(snapshot));
        if (item.identity.source.name != source ||
            item.identity.value != row['content_id']) {
          throw _invalid;
        }
        return {...row, 'snapshot': LibraryCodec.encodeContent(item)};
      }
      if (table == 'collection_items') _id(row['folder_id']);
      if (table == 'watch_later' &&
          (row['done'] is! int || (row['done'] != 0 && row['done'] != 1))) {
        throw _invalid;
      }
      if (table == 'content_history') {
        if (!HistoryAction.values.any((a) => a.name == row['action'])) {
          throw _invalid;
        }
        _number(row['visits'], min: 1);
      }
      // Both playback tables address a part by its source id, so an imported
      // row keeps pointing at the same part even after the source reorders.
      if (table == 'playback_progress' || table == 'playback_bookmarks') {
        _id(row['part_id']);
      }
      if (table == 'playback_progress') {
        _number(row['position_ms']);
        _number(row['duration_ms']);
        final position = row['position_ms'] as int;
        final duration = row['duration_ms'] as int;
        // An unknown duration is 0 and cannot bound the position; a known one
        // must not be shorter than the stored position.
        if ((duration > 0 && position > duration) ||
            row['completed'] is! int ||
            (row['completed'] != 0 && row['completed'] != 1)) {
          throw _invalid;
        }
      }
      if (table == 'playback_bookmarks') {
        _id(row['id']);
        _number(row['start_ms']);
        final end = row['end_ms'];
        // Null stays a point bookmark. A present end may equal the start but
        // never precede it.
        if (end != null) {
          _number(end);
          if ((end as int) < (row['start_ms'] as int)) throw _invalid;
        }
        _text(row['title'], 200);
        _text(row['note'], 2000);
      }
    }
    return row;
  }

  static void _relations(Map<String, List<Map<String, Object?>>> tables) {
    const keys = {
      'preferences': ['key'],
      'content_refs': ['source', 'content_id'],
      'collection_folders': ['id'],
      'collection_items': ['folder_id', 'source', 'content_id'],
      'watch_later': ['source', 'content_id'],
      'content_history': ['source', 'content_id', 'action'],
      'local_subscriptions': ['mid'],
      'calendar_follows': ['source', 'uid', 'recurrence_id'],
      'content_rules': ['id'],
      'rule_settings': ['key'],
      'subscription_reads': ['bvid'],
      'playback_progress': ['source', 'content_id', 'part_id'],
      'playback_bookmarks': ['id'],
    };
    String identity(Map<String, Object?> row) =>
        jsonEncode([row['source'], row['content_id']]);
    for (final entry in tables.entries) {
      final seen = <String>{};
      for (final row in entry.value) {
        if (!seen.add(
          jsonEncode(keys[entry.key]!.map((k) => row[k]).toList()),
        )) {
          throw _invalid;
        }
      }
    }
    final ruleKeys = <String>{};
    for (final row in tables['content_rules']!) {
      if (!ruleKeys.add(
        jsonEncode([row['kind'], row['scope'], row['value']]),
      )) {
        throw _invalid;
      }
    }
    final folders = tables['collection_folders']!
        .map((row) => row['id'])
        .toSet();
    if (!folders.contains('default')) throw _invalid;
    final content = tables['content_refs']!.map(identity).toSet();
    final referenced = <String>{};
    for (final table in [
      'collection_items',
      'watch_later',
      'content_history',
      'playback_progress',
      'playback_bookmarks',
    ]) {
      for (final row in tables[table]!) {
        final key = identity(row);
        if (!content.contains(key)) throw _invalid;
        referenced.add(key);
        if (table == 'collection_items' &&
            !folders.contains(row['folder_id'])) {
          throw _invalid;
        }
      }
    }
    if (referenced.length != content.length) throw _invalid;
  }

  static Map<String, Object?> _object(Object? value, List<String> fields) {
    if (value is! Map<String, dynamic> ||
        value.length != fields.length ||
        fields.any((k) => !value.containsKey(k))) {
      throw _invalid;
    }
    return Map<String, Object?>.from(value);
  }

  static String _text(Object? value, int max) {
    if (value is! String || value.length > max || value.contains('\u0000')) {
      throw _invalid;
    }
    return value;
  }

  static String _id(Object? value) => LibraryCodec.id(_text(value, 256));
  static void _time(Object? value) {
    if (value is! int || value < 0 || value > 253402300799999) throw _invalid;
  }

  static void _number(Object? value, {int min = 0}) {
    if (value is! int || value < min || value > 2147483647) throw _invalid;
  }

  static void _uri(Object? value, {bool nullable = false}) {
    if (nullable && value == null) return;
    if (value is! String ||
        value.contains('\r') ||
        value.contains('\n') ||
        LibraryCodec.publicUri(value) == null) {
      throw _invalid;
    }
  }

  static void _depth(Uint8List bytes) {
    var depth = 0;
    var string = false;
    var escape = false;
    for (final byte in bytes) {
      if (string) {
        if (escape) {
          escape = false;
        } else if (byte == 92) {
          escape = true;
        } else if (byte == 34) {
          string = false;
        }
      } else if (byte == 34) {
        string = true;
      } else if (byte == 123 || byte == 91) {
        if (++depth > 24) throw _invalid;
      } else if (byte == 125 || byte == 93) {
        if (--depth < 0) throw _invalid;
      }
    }
    if (depth != 0 || string) throw _invalid;
  }
}
