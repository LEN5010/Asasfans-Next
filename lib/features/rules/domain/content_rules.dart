import '../../../core/domain/content_identity.dart';

enum RuleKind { content, creator, word, tag }

class RuleDraft {
  const RuleDraft({
    required this.kind,
    required this.value,
    this.scope = '',
    this.enabled = true,
    this.expiresAt,
  });
  final RuleKind kind;
  final String value;
  final String scope;
  final bool enabled;
  final DateTime? expiresAt;

  RuleDraft normalized() {
    final trimmed = value.trim();
    final normalized = kind == RuleKind.word || kind == RuleKind.tag
        ? trimmed.toLowerCase()
        : trimmed;
    if (normalized.isEmpty ||
        normalized.length > 256 ||
        normalized.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const RuleFailure(RuleFailureKind.invalid);
    }
    final validScope = switch (kind) {
      RuleKind.content => ContentSource.values.any((s) => s.name == scope),
      RuleKind.creator => scope == 'bilibili' || scope == 'douban',
      RuleKind.word || RuleKind.tag => scope.isEmpty,
    };
    if (!validScope ||
        (kind == RuleKind.creator &&
            scope == 'bilibili' &&
            !RegExp(r'^[1-9]\d{0,19}$').hasMatch(normalized)) ||
        (expiresAt != null &&
            (expiresAt!.millisecondsSinceEpoch < 0 ||
                expiresAt!.millisecondsSinceEpoch > 253402300799999))) {
      throw const RuleFailure(RuleFailureKind.invalid);
    }
    return RuleDraft(
      kind: kind,
      value: normalized,
      scope: scope,
      enabled: enabled,
      expiresAt: expiresAt?.toUtc(),
    );
  }
}

class ContentRule {
  const ContentRule({
    required this.id,
    required this.draft,
    required this.createdAt,
    required this.updatedAt,
    required this.changeToken,
  });
  final String id;
  final RuleDraft draft;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String changeToken;
  bool activeAt(DateTime now) =>
      draft.enabled &&
      (draft.expiresAt == null || now.isBefore(draft.expiresAt!));
}

class RuleChange {
  const RuleChange({this.before, this.after});
  final ContentRule? before;
  final ContentRule? after;
}

class RulesSnapshot {
  RulesSnapshot({
    required List<ContentRule> rules,
    Set<String> subscriptions = const {},
    this.prioritizeSubscribed = false,
  }) : rules = List.unmodifiable(rules),
       subscriptions = Set.unmodifiable(subscriptions);
  final List<ContentRule> rules;
  final Set<String> subscriptions;
  final bool prioritizeSubscribed;
}

class RuleSubject {
  const RuleSubject({
    required this.identity,
    required this.title,
    this.description = '',
    this.category = '',
    this.creatorScope = '',
    this.creatorId = '',
    this.creatorName = '',
    this.tags,
    this.additionalText = const {},
    this.isVideo = false,
  });
  final ContentIdentity identity;
  final String title;
  final String description;
  final String category;
  final String creatorScope;
  final String creatorId;
  final String creatorName;

  /// null means unknown. Curated character labels are not Bilibili tags.
  final List<String>? tags;
  final Map<String, String> additionalText;
  final bool isVideo;
  String get displayTitle => String.fromCharCodes(title.runes.take(160)).trim();
}

class RuleMatch {
  const RuleMatch({
    required this.ruleId,
    required this.field,
    required this.value,
  });
  final String ruleId;
  final String field;
  final String value;
}

class RuleEvaluation {
  RuleEvaluation({
    required List<RuleMatch> matches,
    required this.tagsUnknown,
    required this.subscribed,
  }) : matches = List.unmodifiable(matches);
  final List<RuleMatch> matches;
  final bool tagsUnknown;
  final bool subscribed;
  bool get blocked => matches.isNotEmpty;
}

/// Shared by every discovery source. No network, widgets or user regex here.
class ContentRuleEvaluator {
  ContentRuleEvaluator(RulesSnapshot snapshot, DateTime now)
    : _rules = snapshot.rules.where((r) => r.activeAt(now)).toList(),
      _subscriptions = snapshot.subscriptions;
  final List<ContentRule> _rules;
  final Set<String> _subscriptions;
  static const builtInCarol = 'builtin:carol';
  static String normalize(String value) => value.trim().toLowerCase();

  RuleEvaluation evaluate(RuleSubject item) {
    final fields = {
      '标题': normalize(item.title),
      '简介': normalize(item.description),
      '分区': normalize(item.category),
      for (final entry in item.additionalText.entries)
        entry.key: normalize(entry.value),
    };
    final tags = item.tags?.map(normalize).toSet();
    final matches = <RuleMatch>[];
    for (final rule in _rules) {
      final draft = rule.draft;
      final field = switch (draft.kind) {
        RuleKind.content =>
          draft.scope == item.identity.source.name &&
                  draft.value == item.identity.value
              ? '内容'
              : null,
        RuleKind.creator =>
          draft.scope == item.creatorScope && draft.value == item.creatorId
              ? '作者'
              : null,
        RuleKind.word =>
          fields.entries
              .where((e) => e.value.contains(draft.value))
              .firstOrNull
              ?.key,
        RuleKind.tag => tags?.contains(draft.value) == true ? 'Tag' : null,
      };
      if (field != null) {
        matches.add(
          RuleMatch(ruleId: rule.id, field: field, value: draft.value),
        );
      }
    }
    // The historical default applied to video lists. Do not silently extend it
    // to all text/image archives merely because these new sources now exist.
    if (item.isVideo) {
      final fields = {
        '标题': item.title,
        '简介': item.description,
        'Tag': item.tags?.join(',') ?? '',
        'UP 名称': item.creatorName,
      };
      final hit =
          item.creatorScope == 'bilibili' && item.creatorId == '351609538'
          ? 'UP'
          : fields.entries
                .where(
                  (e) =>
                      normalize(e.value).contains('珈乐') ||
                      normalize(e.value).contains('carol'),
                )
                .firstOrNull
                ?.key;
      if (hit != null) {
        matches.add(
          RuleMatch(ruleId: builtInCarol, field: hit, value: '默认成员过滤'),
        );
      }
    }
    return RuleEvaluation(
      matches: matches,
      tagsUnknown:
          tags == null && _rules.any((r) => r.draft.kind == RuleKind.tag),
      subscribed:
          item.creatorScope == 'bilibili' &&
          _subscriptions.contains(item.creatorId),
    );
  }
}

enum RuleFailureKind { invalid, changed, limitReached }

class RuleFailure implements Exception {
  const RuleFailure(this.kind);
  final RuleFailureKind kind;
  String get message => switch (kind) {
    RuleFailureKind.invalid => '规则内容无效，请检查',
    RuleFailureKind.changed => '规则已变更或重复，请刷新后重试',
    RuleFailureKind.limitReached => '规则已达 1000 条，请先整理',
  };
  @override
  String toString() => 'RuleFailure(${kind.name})';
}
