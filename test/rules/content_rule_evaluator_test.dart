import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/rules/application/feed_visibility.dart';
import 'package:asasfans_next/features/rules/application/rules_controller.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 9, 21);
ContentRule rule(
  RuleKind kind,
  String value, {
  String scope = '',
  bool enabled = true,
  DateTime? expires,
}) => ContentRule(
  id: '1' * 32,
  draft: RuleDraft(
    kind: kind,
    value: value,
    scope: scope,
    enabled: enabled,
    expiresAt: expires,
  ).normalized(),
  createdAt: now,
  updatedAt: now,
  changeToken: '2' * 32,
);
RuleSubject subject({
  ContentSource source = ContentSource.bilibiliVideo,
  String id = 'BV1',
  String title = '标题',
  String description = '录播',
  String category = '音乐',
  String creator = '123',
  String creatorScope = 'bilibili',
  String name = '作者',
  List<String>? tags = const ['嘉然', '切片'],
  bool video = true,
}) => RuleSubject(
  identity: ContentIdentity(source: source, value: id),
  title: title,
  description: description,
  category: category,
  creatorId: creator,
  creatorScope: creatorScope,
  creatorName: name,
  tags: tags,
  isVideo: video,
);
RuleEvaluation evaluate(RuleSubject subject, List<ContentRule> rules) =>
    ContentRuleEvaluator(RulesSnapshot(rules: rules), now).evaluate(subject);
void main() {
  test(
    'word fields and exact tags preserve different historical semantics',
    () {
      expect(
        evaluate(subject(), [rule(RuleKind.word, ' 嘉然 ')]).blocked,
        isFalse,
      );
      expect(
        evaluate(subject(), [rule(RuleKind.word, '录播')]).matches.single.field,
        '简介',
      );
      expect(
        evaluate(subject(), [rule(RuleKind.word, '音乐')]).matches.single.field,
        '分区',
      );
      expect(evaluate(subject(), [rule(RuleKind.word, '作者')]).blocked, isFalse);
      expect(evaluate(subject(), [rule(RuleKind.tag, '切')]).blocked, isFalse);
      expect(evaluate(subject(), [rule(RuleKind.tag, ' 切片 ')]).blocked, isTrue);
      expect(
        evaluate(subject(tags: ['CLIP']), [rule(RuleKind.tag, 'clip')]).blocked,
        isTrue,
      );
      expect(
        evaluate(subject(title: '.*'), [rule(RuleKind.word, '.*')]).blocked,
        isTrue,
      );
      expect(
        evaluate(subject(title: '其他'), [rule(RuleKind.word, '.*')]).blocked,
        isFalse,
      );
    },
  );
  test(
    'source-scoped content and creator identities cannot collide across platforms',
    () {
      final content = rule(RuleKind.content, '123', scope: 'bilibiliDynamic');
      expect(
        evaluate(subject(source: ContentSource.bilibiliDynamic, id: '123'), [
          content,
        ]).blocked,
        isTrue,
      );
      expect(
        evaluate(subject(source: ContentSource.doubanTopic, id: '123'), [
          content,
        ]).blocked,
        isFalse,
      );
      final creator = rule(RuleKind.creator, '123', scope: 'bilibili');
      expect(
        evaluate(subject(creatorScope: 'bilibili'), [creator]).blocked,
        isTrue,
      );
      expect(
        evaluate(subject(creatorScope: 'douban'), [creator]).blocked,
        isFalse,
      );
    },
  );
  test(
    'unknown tags, disabled and expired rules do not silently change meaning',
    () {
      final tag = rule(RuleKind.tag, '嘉然');
      expect(evaluate(subject(tags: null), [tag]).tagsUnknown, isTrue);
      expect(evaluate(subject(tags: []), [tag]).tagsUnknown, isFalse);
      expect(
        evaluate(subject(tags: null), [
          rule(RuleKind.tag, '嘉然', enabled: false),
        ]).tagsUnknown,
        isFalse,
      );
      expect(
        evaluate(subject(), [rule(RuleKind.word, '标题', expires: now)]).blocked,
        isFalse,
      );
      expect(
        evaluate(subject(), [
          rule(
            RuleKind.word,
            '标题',
            expires: now.add(const Duration(milliseconds: 1)),
          ),
        ]).blocked,
        isTrue,
      );
    },
  );
  test(
    'default Carol video policy is preserved but is not expanded to all image archives',
    () {
      for (final value in [
        subject(title: '珈乐歌切'),
        subject(creator: '351609538'),
        subject(description: 'CAROL'),
        subject(tags: ['Carol']),
        subject(name: 'Carol'),
      ]) {
        expect(
          evaluate(value, []).matches.single.ruleId,
          ContentRuleEvaluator.builtInCarol,
        );
      }
      expect(evaluate(subject(category: '珈乐'), []).blocked, isFalse);
      expect(
        evaluate(subject(title: 'Carol', video: false), []).blocked,
        isFalse,
      );
      expect(
        evaluate(
          subject(creator: '351609538', creatorScope: 'douban'),
          [],
        ).blocked,
        isFalse,
      );
    },
  );
  test(
    'explicit blocking wins over subscription priority; stable partition never mutates raw ordering',
    () {
      final values = [
        subject(id: '1', creator: '1'),
        subject(id: '2', creator: '2'),
        subject(id: '3', creator: '3'),
        subject(id: '4', creator: '2'),
      ];
      final snapshot = RulesSnapshot(
        rules: [rule(RuleKind.content, '4', scope: 'bilibiliVideo')],
        subscriptions: {'2'},
        prioritizeSubscribed: true,
      );
      final result = projectFeed(
        values,
        (v) => v,
        RulesState(snapshot: snapshot, loading: false, now: now),
      );
      expect(result.items.map((v) => v.identity.value), ['2', '1', '3']);
      expect(result.hidden.single.subject.identity.value, '4');
      expect(values.map((v) => v.identity.value), ['1', '2', '3', '4']);
      final chronological = projectFeed(
        values,
        (v) => v,
        RulesState(snapshot: snapshot, loading: false, now: now),
        allowPriority: false,
      );
      expect(chronological.items.map((v) => v.identity.value), ['1', '2', '3']);
    },
  );
  test(
    'curated member labels are not invented upstream tags or partitions',
    () {
      final fanart = FanartItem(
        identity: const ContentIdentity(
          source: ContentSource.bilibiliDynamic,
          value: '1',
        ),
        text: '作品',
        authorName: '作者',
        authorUid: '123',
        images: const [],
        kind: FanartKind.fanart,
        contentType: FanartContentType.video,
        category: FanartCategory.amv,
        characterTags: const [FanartCharacter.diana],
      );
      final mapped = RuleSubjects.fanart(fanart);
      expect(mapped.tags, isNull);
      expect(mapped.category, isEmpty);
      final known = RuleSubjects.video(
        const CommunityVideo(
          identity: ContentIdentity(
            source: ContentSource.bilibiliVideo,
            value: 'BV1',
          ),
          title: '作品',
          creatorName: '作者',
          creatorId: '123',
          tags: ['嘉然'],
        ),
      );
      final tag = rule(RuleKind.tag, '嘉然');
      expect(evaluate(mapped, [tag]).tagsUnknown, isTrue);
      expect(evaluate(known, [tag]).blocked, isTrue);
    },
  );
}
