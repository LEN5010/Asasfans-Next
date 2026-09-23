import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/library_common.dart';
import '../application/backup_providers.dart';
import '../data/backup_files.dart';
import '../domain/personal_backup.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  bool _merging = false;
  bool _previewing = false;
  String? _status;
  bool _failed = false;

  Future<void> _perform(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
      _failed = false;
    });
    try {
      final result = await action();
      if (mounted) setState(() => _status = result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error is BackupFailure
              ? error.message
              : libraryError(error);
          _failed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _merging = false;
          _previewing = false;
        });
      }
    }
  }

  Future<void> _export(BuildContext anchor) {
    final box = anchor.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final repository = ref.read(backupRepositoryProvider);
    final files = ref.read(backupFilesProvider);
    return _perform(() async {
      final bytes = await repository.export();
      if (!mounted) return '';
      final result = await files.save(bytes, origin);
      return switch (result) {
        BackupExportResult.saved => '备份已保存',
        BackupExportResult.shared => '已交给系统分享',
        BackupExportResult.dismissed => '已取消导出',
        BackupExportResult.unknown => '已打开系统分享，请确认文件是否保存',
      };
    });
  }

  Future<void> _import() {
    final repository = ref.read(backupRepositoryProvider);
    final files = ref.read(backupFilesProvider);
    return _perform(() async {
      final bytes = await files.pick();
      if (!mounted) return '';
      if (bytes == null) return '已取消导入';
      final backup = await repository.inspect(bytes);
      if (!mounted) return '';
      setState(() => _previewing = true);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ImportPreview(summary: backup.summary),
      );
      if (!mounted) return '';
      setState(() => _previewing = false);
      if (confirmed != true) return '已取消导入';
      setState(() => _merging = true);
      await repository.merge(backup);
      return '备份已合并';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_merging,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('备份与恢复')),
      body: LibraryBody(
        child: ListView(
          padding: pageInsets(context, top: 4),
          children: [
            if (_busy && !_previewing) const LinearProgressIndicator(),
            Card(
              child: Column(
                children: [
                  Builder(
                    builder: (anchor) => ListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('导出备份'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_busy,
                      onTap: () => _export(anchor),
                    ),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('导入备份'),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_busy,
                    onTap: _import,
                  ),
                ],
              ),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _status!,
                  style: TextStyle(
                    color: _failed ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({required this.summary});
  final BackupSummary summary;
  @override
  Widget build(BuildContext context) {
    final time = summary.exportedAt.toLocal();
    return AlertDialog(
      title: const Text('合并此备份？'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('导出于 ${time.year}-${time.month}-${time.day}'),
              const SizedBox(height: 16),
              const Text('备份包含'),
              for (final entry in const {
                'collection_folders': '收藏夹',
                'collection_items': '收藏',
                'watch_later': '稍后看',
                'content_history': '历史记录',
                'local_subscriptions': '本地订阅',
                'calendar_follows': '关注日程',
                'preferences': '偏好设置',
                'content_rules': '内容规则',
                'rule_settings': '规则设置',
                'subscription_reads': '更新已读状态',
                'saved_channels': '保存的频道',
              }.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${entry.value}：${summary.counts[entry.key] ?? 0} 项',
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                '不清空现有资料。重复收藏、稍后看、订阅、已读状态、规则和偏好保留本机设置；内容、历史和日程合并较新记录。',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认合并'),
        ),
      ],
    );
  }
}
