import 'dart:typed_data';

class BackupSummary {
  BackupSummary({required this.exportedAt, required Map<String, int> counts})
    : counts = Map.unmodifiable(counts);
  final DateTime exportedAt;
  final Map<String, int> counts;
}

/// Implementations hold the validated in-memory data, not a filename that can
/// change after preview. Import is merge-only and never deletes local assets.
abstract interface class BackupImport {
  BackupSummary get summary;
}

abstract interface class BackupRepository {
  Future<Uint8List> export();
  Future<BackupImport> inspect(Uint8List bytes);
  Future<void> merge(BackupImport backup);
}

enum BackupFailureKind { invalid, incompatible, tooLarge, fileAccess }

class BackupFailure implements Exception {
  const BackupFailure(this.kind);
  final BackupFailureKind kind;
  String get message => switch (kind) {
    BackupFailureKind.invalid => '备份内容不完整或已损坏',
    BackupFailureKind.incompatible => '备份版本不兼容，请更新应用',
    BackupFailureKind.tooLarge => '备份超过当前大小或条数上限',
    BackupFailureKind.fileAccess => '文件无法读写，请重试',
  };
  @override
  String toString() => 'BackupFailure(${kind.name})';
}
