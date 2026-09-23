import '../../../shared/widgets/app_panel.dart';
import 'package:flutter/material.dart';

import '../domain/content_rules.dart';
import '../domain/rules_repository.dart';
import 'rule_common.dart';
import 'rule_editor.dart';

Future<RuleChange?> requestContentRule(
  BuildContext context,
  RulesRepository repository,
  RuleSubject subject,
) => showAppPanel<RuleChange>(
  context: context,

  maxWidth: 600,
  builder: (_) => _BlockingActions(repository: repository, subject: subject),
);

class _BlockingActions extends StatefulWidget {
  const _BlockingActions({required this.repository, required this.subject});
  final RulesRepository repository;
  final RuleSubject subject;
  @override
  State<_BlockingActions> createState() => _BlockingActionsState();
}

class _BlockingActionsState extends State<_BlockingActions> {
  bool _busy = false;
  String? _error;
  Future<void> _save(RuleDraft draft) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final change = await widget.repository.save(draft);
      if (mounted) Navigator.pop(context, change);
    } catch (error) {
      if (mounted) setState(() => _error = ruleError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final canBlockCreator =
        subject.creatorId.trim().isNotEmpty &&
        (subject.creatorScope != 'bilibili' ||
            RegExp(r'^[1-9]\d{0,19}$').hasMatch(subject.creatorId));
    final tags =
        subject.tags
            ?.map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList() ??
        <String>[];
    return PopScope(
      canPop: !_busy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPanelHeader(title: subject.displayTitle, canClose: !_busy),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.hide_source),
                title: const Text('屏蔽此内容'),
                enabled: !_busy,
                onTap: () => _save(
                  RuleDraft(
                    kind: RuleKind.content,
                    scope: subject.identity.source.name,
                    value: subject.identity.value,
                  ),
                ),
              ),
              if (canBlockCreator) ...[
                ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('屏蔽此作者'),
                  enabled: !_busy,
                  onTap: () => _save(
                    RuleDraft(
                      kind: RuleKind.creator,
                      scope: subject.creatorScope,
                      value: subject.creatorId,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.snooze_outlined),
                  title: const Text('静音此作者 1 天'),
                  enabled: !_busy,
                  onTap: () => _save(
                    RuleDraft(
                      kind: RuleKind.creator,
                      scope: subject.creatorScope,
                      value: subject.creatorId,
                      expiresAt: DateTime.now().toUtc().add(
                        const Duration(days: 1),
                      ),
                    ),
                  ),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('添加屏蔽词'),
                enabled: !_busy,
                onTap: () async {
                  final change = await editRule(context, widget.repository);
                  if (change != null && context.mounted) {
                    Navigator.pop(context, change);
                  }
                },
              ),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in tags)
                        ActionChip(
                          avatar: const Icon(Icons.tag, size: 16),
                          label: Text(tag),
                          onPressed: _busy
                              ? null
                              : () => _save(
                                  RuleDraft(kind: RuleKind.tag, value: tag),
                                ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
