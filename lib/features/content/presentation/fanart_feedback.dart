import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_controls.dart';
import '../application/content_providers.dart';
import '../domain/fanart_repository.dart';

class FanartFeedbackButton extends StatelessWidget {
  const FanartFeedbackButton({required this.item, super.key});
  final FanartItem item;

  @override
  Widget build(BuildContext context) => AppButton.icon(
    tooltip: '反馈问题',
    icon: const Icon(Icons.help_outline, size: 18),
    onPressed: () async {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (_) => _FeedbackDialog(item: item),
      );
      if (submitted == true && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('反馈已提交')));
      }
    },
  );
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog({required this.item});
  final FanartItem item;

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _detail = TextEditingController();
  var _reason = FanartFeedbackReason.wrongCharacter;
  bool _submitting = false;
  bool _failed = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      await ref
          .read(fanartFeedbackRepositoryProvider)
          .submit(
            identity: widget.item.identity,
            reason: _reason,
            detail: _detail.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: const Text('反馈问题'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<FanartFeedbackReason>(
              groupValue: _reason,
              onChanged: (value) {
                if (value != null && !_submitting) {
                  setState(() => _reason = value);
                }
              },
              child: Column(
                children: [
                  for (final reason in FanartFeedbackReason.values)
                    RadioListTile<FanartFeedbackReason>(
                      value: reason,
                      enabled: !_submitting,
                      contentPadding: EdgeInsets.zero,
                      title: Text(switch (reason) {
                        FanartFeedbackReason.wrongCharacter => '人物识别错误',
                        FanartFeedbackReason.wrongCategory => '分类不合理',
                        FanartFeedbackReason.contentIssue => '内容存在问题',
                        FanartFeedbackReason.other => '其他',
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detail,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              // Leave room for the character-error label in the API detail.
              maxLength: 993,
              decoration: const InputDecoration(
                labelText: '补充说明（可选）',
                counterText: '',
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              Text(
                '提交失败，请重试',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('提交'),
        ),
      ],
    ),
  );
}
