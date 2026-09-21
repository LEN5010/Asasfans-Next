import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/features/backup/data/backup_codec.dart';

/// The table set each backup format version was actually released with.
const _columnsByVersion = <int, Map<String, List<String>>>{
  1: BackupCodec.columnsV1,
  2: BackupCodec.columnsV2,
  3: BackupCodec.columnsV3,
  4: BackupCodec.columnsV4,
  5: BackupCodec.columns,
};

/// Rewrites a current export as a file the given [version] could really have
/// produced: exactly that version's tables, no more and no fewer.
///
/// Relabelling a current file and deleting a few keys by hand does not produce
/// an old file. The decoder requires an exact key set per version, so a leftover
/// newer table makes it reject a fixture that no released version ever wrote,
/// which tests nothing about backward compatibility.
Uint8List downgradeBackup(Uint8List current, int version) {
  final fields = _columnsByVersion[version];
  if (fields == null) {
    throw ArgumentError.value(version, 'version', 'unsupported backup version');
  }
  final root = jsonDecode(utf8.decode(current)) as Map<String, dynamic>;
  final data = root['data'] as Map<String, dynamic>;
  root['version'] = version;
  root['data'] = {
    for (final table in fields.keys) table: data[table] ?? <Object?>[],
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(root)));
}
