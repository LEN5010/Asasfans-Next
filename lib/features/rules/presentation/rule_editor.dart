import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';

import '../domain/content_rules.dart';
import '../domain/rules_repository.dart';
import 'rule_common.dart';

Future<RuleChange?> editRule(
  BuildContext context,
  RulesRepository repository, {
  ContentRule? previous,
  RuleDraft? initial,
}) => showDialog<RuleChange>(
  context: context,
  builder: (_) =>
      _RuleEditor(repository: repository, previous: previous, initial: initial),
);

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.repository, this.previous, this.initial});
  final RulesRepository repository;
  final ContentRule? previous;
  final RuleDraft? initial;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late RuleKind _kind;
  late String _scope;
  late TextEditingController _value;
  int _expiry = -1;
  bool _busy = false;
  String? _error;
  RuleDraft get _initial =>
      widget.previous?.draft ??
      widget.initial ??
      const RuleDraft(kind: RuleKind.word, value: '');
  @override
  void initState() {
    super.initState();
    _kind = _initial.kind;
    _scope = _initial.scope;
    _value = TextEditingController(text: _initial.value);
    _expiry = _initial.expiresAt == null ? 0 : -1;
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final expires = _expiry == -1
          ? _initial.expiresAt
          : _expiry == 0
          ? null
          : DateTime.now().toUtc().add(Duration(days: _expiry));
      final draft = RuleDraft(
        kind: _kind,
        scope: _scope,
        value: _value.text,
        enabled: _initial.enabled,
        expiresAt: expires,
      ).normalized();
      final change = await widget.repository.save(
        draft,
        previous: widget.previous,
      );
      if (mounted) Navigator.pop(context, change);
    } catch (error) {
      if (mounted) setState(() => _error = ruleError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.previous == null ? '添加屏蔽规则' : '编辑规则'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RuleKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '规则类型'),
                items: [
                  for (final kind in RuleKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(ruleKindLabel(kind)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (kind) {
                        if (kind != null) {
                          setState(() {
                            _kind = kind;
                            _scope = kind == RuleKind.content
                                ? 'bilibiliVideo'
                                : kind == RuleKind.creator
                                ? 'bilibili'
                                : '';
                          });
                        }
                      },
              ),
              if (_kind == RuleKind.content || _kind == RuleKind.creator)
                DropdownButtonFormField<String>(
                  key: ValueKey((_kind, _scope)),
                  initialValue: _scope,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '来源'),
                  items: [
                    for (final scope
                        in _kind == RuleKind.content
                            ? [
                                'bilibiliVideo',
                                'bilibiliDynamic',
                                'doubanTopic',
                              ]
                            : ['bilibili', 'douban'])
                      DropdownMenuItem(
                        value: scope,
                        child: Text(ruleScopeLabel(scope)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (scope) {
                          if (scope != null) setState(() => _scope = scope);
                        },
                ),
              TextField(
                controller: _value,
                maxLength: 256,
                enabled: !_busy,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _kind == RuleKind.content
                      ? '内容 ID'
                      : _kind == RuleKind.creator
                      ? '作者 ID'
                      : ruleKindLabel(_kind),
                ),
                onSubmitted: (_) => _save(),
              ),
              DropdownButtonFormField<int>(
                initialValue: _expiry,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '有效期'),
                items: const [
                  DropdownMenuItem(value: -1, child: Text('保持原设置')),
                  DropdownMenuItem(value: 0, child: Text('长期')),
                  DropdownMenuItem(value: 1, child: Text('1 天')),
                  DropdownMenuItem(value: 7, child: Text('7 天')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _expiry = value);
                      },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        AppGlassButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        AppGlassButton(
          selected: true,
          onPressed: _busy ? null : _save,
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
