import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/personal_backup.dart';
import 'backup_codec.dart';

enum BackupExportResult { saved, shared, dismissed, unknown }

abstract interface class BackupFiles {
  Future<Uint8List?> pick();
  Future<BackupExportResult> save(Uint8List bytes, Rect origin);
}

/// System document pickers only. No broad storage permission or filesystem
/// scan. Desktop save and mobile sharing are deliberately different outcomes.
class PlatformBackupFiles implements BackupFiles {
  static const _type = XTypeGroup(
    label: 'JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );
  @override
  Future<Uint8List?> pick() async {
    try {
      final file = await openFile(acceptedTypeGroups: [_type]);
      if (file == null) return null;
      if (await file.length() > BackupCodec.maxBytes) {
        throw const BackupFailure(BackupFailureKind.tooLarge);
      }
      return await readLimited(file.openRead());
    } on BackupFailure {
      rethrow;
    } catch (_) {
      throw const BackupFailure(BackupFailureKind.fileAccess);
    }
  }

  static Future<Uint8List> readLimited(Stream<List<int>> stream) async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (buffer.length + chunk.length > BackupCodec.maxBytes) {
        throw const BackupFailure(BackupFailureKind.tooLarge);
      }
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }

  @override
  Future<BackupExportResult> save(Uint8List bytes, Rect origin) async {
    try {
      final now = DateTime.now().toUtc();
      final name =
          'asasfans-${now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.json';
      if (Platform.isIOS || Platform.isAndroid) {
        final directory = Directory(
          path.join((await getTemporaryDirectory()).path, 'asasfans_backups'),
        );
        await directory.create(recursive: true);
        try {
          await _cleanup(directory, now);
        } on FileSystemException {
          // A failed listing must not prevent writing a fresh export.
        }
        final exportDirectory = await directory.createTemp('export-');
        final file = File(path.join(exportDirectory.path, name));
        await file.writeAsBytes(bytes, flush: true);
        // Keep files after returning: Android's receiver may still be reading.
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            title: '导出备份',
            sharePositionOrigin: origin,
          ),
        );
        return switch (result.status) {
          ShareResultStatus.success => BackupExportResult.shared,
          ShareResultStatus.dismissed => BackupExportResult.dismissed,
          ShareResultStatus.unavailable => BackupExportResult.unknown,
        };
      }
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [_type],
      );
      if (location == null) return BackupExportResult.dismissed;
      await XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: name,
      ).saveTo(location.path);
      return BackupExportResult.saved;
    } on BackupFailure {
      rethrow;
    } catch (_) {
      throw const BackupFailure(BackupFailureKind.fileAccess);
    }
  }

  static Future<void> _cleanup(Directory root, DateTime now) async {
    // Only our own temporary export subdirectories, never selected user files.
    // No eager deletion of a just-shared file or a symlink target.
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !path.basename(entry.path).startsWith('export-')) {
        continue;
      }
      try {
        if (now.difference((await entry.stat()).modified) >
            const Duration(days: 7)) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        /* Cache cleanup must not prevent exporting. */
      }
    }
  }
}
