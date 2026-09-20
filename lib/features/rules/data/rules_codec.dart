import '../../../core/storage/storage_failure.dart';
import '../domain/content_rules.dart';

abstract final class RulesCodec {
  static const maxRules = 1000;
  static DateTime time(Object? value) {
    if (value is! int || value < 0 || value > 253402300799999) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  static String id(Object? value) {
    if (value is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(value)) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return value;
  }

  static RuleDraft draft(Map<String, Object?> row) {
    final kind = RuleKind.values.byName(row['kind'] as String);
    final scope = row['scope'] as String;
    final value = row['value'] as String;
    if (row['enabled'] is! int ||
        (row['enabled'] != 0 && row['enabled'] != 1)) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final draft = RuleDraft(
      kind: kind,
      scope: scope,
      value: value,
      enabled: row['enabled'] == 1,
      expiresAt: row['expires_at'] == null ? null : time(row['expires_at']),
    ).normalized();
    if (draft.value != value) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return draft;
  }

  static ContentRule decode(Map<String, Object?> row) {
    try {
      final rule = ContentRule(
        id: id(row['id']),
        draft: draft(row),
        createdAt: time(row['created_at']),
        updatedAt: time(row['updated_at']),
        changeToken: id(row['change_token']),
      );
      if (rule.updatedAt.isBefore(rule.createdAt)) {
        throw const StorageFailure(StorageFailureKind.invalidData);
      }
      return rule;
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
  }

  static void validateBackup(Map<String, Object?> row) =>
      decode({...row, 'change_token': '0' * 32});
}
