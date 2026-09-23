import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/library_common.dart';
import '../application/rules_providers.dart';
import '../domain/content_rules.dart';
import 'rule_common.dart';
import 'rule_editor.dart';

class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key});
  @override
  ConsumerState<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends ConsumerState<RulesPage> {
  bool _busy = false;
  RuleKind? _filter;
  Future<void> _act(
    Future<RuleChange> Function() action, {
    String label = '规则已保存',
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repository = ref.read(rulesRepositoryProvider);
    try {
      final change = await action();
      if (mounted) showRuleUndo(context, repository, change, label: label);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ruleError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(rulesControllerProvider);
    final repository = ref.read(rulesRepositoryProvider);
    final rules =
        policy.snapshot?.rules
            .where((r) => _filter == null || r.draft.kind == _filter)
            .toList() ??
        <ContentRule>[];
    final disabled = _busy || !policy.ready;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        title: const Text('内容规则'),
        actions: [
          IconButton(
            tooltip: '刷新规则',
            onPressed: _busy
                ? null
                : () => ref.read(rulesControllerProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '添加规则',
            onPressed: disabled
                ? null
                : () async {
                    final change = await editRule(context, repository);
                    if (change != null && context.mounted) {
                      showRuleUndo(context, repository, change);
                    }
                  },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: LibraryBody(
        child: ListView(
          padding: pageInsets(context, horizontal: 12, top: 4),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('订阅优先'),
                    secondary: const Icon(Icons.person_pin_outlined),
                    value: policy.snapshot?.prioritizeSubscribed ?? false,
                    onChanged: disabled
                        ? null
                        : (value) async {
                            setState(() => _busy = true);
                            await libraryAction(
                              context,
                              () => repository.setSubscriptionPriority(value),
                            );
                            if (mounted) setState(() => _busy = false);
                          },
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.filter_alt_outlined),
                    title: const Text('视频默认过滤'),
                    subtitle: const Text('珈乐 · Carol'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('视频默认过滤'),
                        content: const Text(
                          'UID 351609538\n标题、简介、Tag、UP 名称：珈乐 / Carol',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final kind in [null, ...RuleKind.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(kind == null ? '全部' : ruleKindLabel(kind)),
                        selected: _filter == kind,
                        onSelected: (_) => setState(() => _filter = kind),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_busy) const LinearProgressIndicator(),
            if (policy.loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!policy.ready)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(ruleError(policy.failure!)),
                    TextButton(
                      onPressed: () =>
                          ref.read(rulesControllerProvider.notifier).reload(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            else if (rules.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('没有屏蔽规则')),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < rules.length; index++) ...[
                      if (index > 0) const Divider(indent: 56),
                      Builder(
                        builder: (context) {
                          final rule = rules[index];
                          final draft = rule.draft;
                          final expiry = draft.expiresAt?.toLocal();
                          return ListTile(
                            leading: Icon(ruleIcon(draft.kind)),
                            title: Text(
                              draft.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                ruleKindLabel(draft.kind),
                                if (draft.scope.isNotEmpty)
                                  ruleScopeLabel(draft.scope),
                                if (expiry != null)
                                  policy.now.isBefore(draft.expiresAt!)
                                      ? '至 ${expiry.year}-${expiry.month}-${expiry.day} ${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}'
                                      : '已到期',
                              ].join(' · '),
                            ),
                            onTap: disabled
                                ? null
                                : () async {
                                    final change = await editRule(
                                      context,
                                      repository,
                                      previous: rule,
                                    );
                                    if (change != null && context.mounted) {
                                      showRuleUndo(context, repository, change);
                                    }
                                  },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: draft.enabled,
                                  onChanged: disabled
                                      ? null
                                      : (value) => _act(
                                          () => repository.save(
                                            RuleDraft(
                                              kind: draft.kind,
                                              scope: draft.scope,
                                              value: draft.value,
                                              enabled: value,
                                              expiresAt: draft.expiresAt,
                                            ),
                                            previous: rule,
                                          ),
                                        ),
                                ),
                                IconButton(
                                  tooltip: '删除规则',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: disabled
                                      ? null
                                      : () => _act(
                                          () => repository.remove(rule),
                                          label: '规则已删除',
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
