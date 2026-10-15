import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_controls.dart';
import '../application/release_providers.dart';
import '../domain/app_release.dart';

/// Checks for a newer release once per launch and mentions it in a
/// SnackBar. A failed check stays quiet here: it proves nothing either way,
/// and 检查更新 in 我的 reports it. Debug builds never check on their own.
class ReleaseNotice extends ConsumerStatefulWidget {
  const ReleaseNotice({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<ReleaseNotice> createState() => _ReleaseNoticeState();
}

class _ReleaseNoticeState extends ConsumerState<ReleaseNotice> {
  @override
  void initState() {
    super.initState();
    if (!kDebugMode) unawaited(_check());
  }

  Future<void> _check() async {
    final AppRelease? release;
    try {
      release = await ref.read(releaseCheckProvider.notifier).check();
    } on Object {
      return;
    }
    if (release == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('发现新版本 ${release.version}'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => showReleaseDialog(context, release!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 检查更新 from 我的: the newer release in a dialog, or a line saying this
/// build is the newest or why the check failed.
Future<void> checkForUpdates(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final AppRelease? release;
  try {
    release = await ref.read(releaseCheckProvider.notifier).check();
  } on ApiFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text('检查更新失败：${failure.message}')),
    );
    return;
  }
  if (!context.mounted) return;
  if (release == null) {
    messenger.showSnackBar(SnackBar(content: Text('已是最新版本 $currentVersion')));
  } else {
    await showReleaseDialog(context, release);
  }
}

Future<void> showReleaseDialog(BuildContext context, AppRelease release) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ReleaseDialog(release: release),
    );

class _ReleaseDialog extends ConsumerWidget {
  const _ReleaseDialog({required this.release});
  final AppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = release.publishedAt?.toLocal();
    final notes = plainNotes(release.notes);
    return AlertDialog(
      icon: const Icon(Icons.system_update_outlined),
      title: Text('新版本 ${release.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                '当前 $currentVersion',
                if (release.preRelease) '预发布版',
                if (date != null)
                  '${date.year}-${_two(date.month)}-${_two(date.day)} 发布',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(notes, style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        AppButton(
          selected: true,
          onPressed: () async {
            final opened = await ref
                .read(externalLinkServiceProvider)
                .open(release.page);
            if (!context.mounted) return;
            if (opened) {
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('无法打开 ${release.page}')));
            }
          },
          child: const Text('前往下载'),
        ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Release notes are Markdown; without a renderer, the marks come off and
/// list items keep a bullet.
@visibleForTesting
String plainNotes(String markdown) => [
  for (final line in markdown.split('\n'))
    line
        .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
        .replaceFirstMapped(
          RegExp(r'^(\s*)[-*]\s+'),
          (match) => '${match[1]}• ',
        )
        .replaceAll('**', '')
        .replaceAll('`', ''),
].join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
