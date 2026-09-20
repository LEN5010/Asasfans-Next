import 'package:flutter/material.dart';

import '../../library/presentation/library_common.dart';
import '../domain/content_rules.dart';
import '../domain/rules_repository.dart';

String ruleError(Object error) =>
    error is RuleFailure ? error.message : libraryError(error);
String ruleKindLabel(RuleKind kind) => switch (kind) {
  RuleKind.content => '内容',
  RuleKind.creator => '作者',
  RuleKind.word => '屏蔽词',
  RuleKind.tag => '精确 Tag',
};
IconData ruleIcon(RuleKind kind) => switch (kind) {
  RuleKind.content => Icons.hide_source,
  RuleKind.creator => Icons.person_off_outlined,
  RuleKind.word => Icons.text_fields,
  RuleKind.tag => Icons.tag,
};
String ruleScopeLabel(String scope) => switch (scope) {
  'bilibiliVideo' => 'B 站视频',
  'bilibiliDynamic' => 'B 站动态',
  'doubanTopic' => '豆瓣帖子',
  'bilibili' => 'B 站',
  'douban' => '豆瓣',
  _ => '',
};
void showRuleUndo(
  BuildContext context,
  RulesRepository repository,
  RuleChange change, {
  String label = '规则已保存',
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(label),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () async {
          try {
            final undone = await repository.undo(change);
            if (messenger.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(undone ? '已撤销' : '规则已变更，未撤销')),
              );
            }
          } catch (error) {
            if (messenger.mounted) {
              messenger.showSnackBar(SnackBar(content: Text(ruleError(error))));
            }
          }
        },
      ),
    ),
  );
}
