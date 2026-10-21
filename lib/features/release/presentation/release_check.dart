import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_controls.dart';
import '../application/release_providers.dart';
import '../domain/app_release.dart';

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

/// The site's download page with this platform picked; it offers mirrors
/// for networks that cannot reach GitHub.
Uri downloadPage(TargetPlatform platform) =>
    Uri.https('len5010.top', '/download', {'p': platform.name.toLowerCase()});

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
          onPressed: () => _open(context, ref, release.page),
          child: const Text('发布页面'),
        ),
        AppButton(
          selected: true,
          onPressed: () =>
              _open(context, ref, downloadPage(defaultTargetPlatform)),
          child: const Text('前往下载'),
        ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final opened = await ref.read(externalLinkServiceProvider).open(uri);
    if (!context.mounted) return;
    if (opened) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开 $uri')));
    }
  }
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
