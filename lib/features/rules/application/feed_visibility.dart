import '../../../core/domain/content_identity.dart';
import '../../../core/domain/video_summary.dart';
import '../../content/domain/dynamic_repository.dart';
import '../../content/domain/fanart_repository.dart';
import '../../library/domain/library_models.dart';
import '../domain/content_rules.dart';
import 'rules_controller.dart';

abstract final class RuleSubjects {
  static String _scope(ContentIdentity id) =>
      id.source == ContentSource.doubanTopic ? 'douban' : 'bilibili';
  static RuleSubject fanart(FanartItem item) => RuleSubject(
    identity: item.identity,
    title: item.text,
    creatorScope: _scope(item.identity),
    creatorId: item.authorUid,
    creatorName: item.authorName,
    isVideo: item.contentType == FanartContentType.video,
  );
  static RuleSubject video(VideoSummary item) => RuleSubject(
    identity: item.identity,
    title: item.title,
    description: item.description,
    category: item.category,
    creatorScope: 'bilibili',
    creatorId: item.creatorId,
    creatorName: item.creatorName,
    tags: item.tags,
    isVideo: true,
  );
  static RuleSubject dynamic(DynamicPost item) => RuleSubject(
    identity: item.identity,
    title: item.text,
    creatorScope: 'bilibili',
    creatorId: item.member.bilibiliUid,
    creatorName: item.member.name,
    isVideo: item.type == DynamicType.video,
    additionalText: {
      if (item.forwardedFrom != null) '转发正文': item.forwardedFrom!.text,
    },
  );
  static RuleSubject saved(ContentSnapshot item) => RuleSubject(
    identity: item.identity,
    title: item.title,
    description: item.body,
    creatorScope: _scope(item.identity),
    creatorId: item.authorId,
    creatorName: item.authorName,
    isVideo: item.kind == LibraryMediaKind.video,
  );
}

class HiddenContent<T> {
  const HiddenContent({
    required this.item,
    required this.subject,
    required this.evaluation,
  });
  final T item;
  final RuleSubject subject;
  final RuleEvaluation evaluation;
}

class FeedVisibility<T> {
  FeedVisibility({
    required List<T> items,
    required List<HiddenContent<T>> hidden,
    required this.tagsUnknownCount,
    required this.prioritized,
    required this.epoch,
  }) : items = List.unmodifiable(items),
       hidden = List.unmodifiable(hidden);
  final List<T> items;
  final List<HiddenContent<T>> hidden;

  // Only user-authored rules have a product-facing history. Raw hidden rows
  // remain available to the existing projection/pagination logic.
  List<HiddenContent<T>> get userHidden => hidden
      .where(
        (entry) => !entry.evaluation.matches.any(
          (match) => match.ruleId == ContentRuleEvaluator.builtInCarol,
        ),
      )
      .toList();
  final int tagsUnknownCount;
  final bool prioritized;
  final int epoch;
}

/// Projects raw, cursor-owning feed state; hidden entries remain available for
/// undo and never count as an empty/duplicate upstream page.
FeedVisibility<T> projectFeed<T>(
  List<T> raw,
  RuleSubject Function(T) subjectOf,
  RulesState policy, {
  bool allowPriority = true,
}) {
  if (!policy.ready) throw StateError('Rules are not ready');
  final snapshot = policy.snapshot!;
  final evaluator = ContentRuleEvaluator(snapshot, policy.now);
  final normal = <T>[];
  final subscribed = <T>[];
  final hidden = <HiddenContent<T>>[];
  var unknown = 0;
  final priority = allowPriority && snapshot.prioritizeSubscribed;
  for (final item in raw) {
    final subject = subjectOf(item);
    final evaluation = evaluator.evaluate(subject);
    if (evaluation.tagsUnknown &&
        !evaluation.matches.any(
          (match) => match.ruleId == ContentRuleEvaluator.builtInCarol,
        )) {
      unknown++;
    }
    if (evaluation.blocked) {
      hidden.add(
        HiddenContent(item: item, subject: subject, evaluation: evaluation),
      );
    } else if (priority && evaluation.subscribed) {
      subscribed.add(item);
    } else {
      normal.add(item);
    }
  }
  return FeedVisibility(
    items: [...subscribed, ...normal],
    hidden: hidden,
    tagsUnknownCount: unknown,
    prioritized: priority && subscribed.isNotEmpty,
    epoch: policy.epoch,
  );
}
