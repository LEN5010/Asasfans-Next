import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_providers.dart';

class OperationsRepository {
  OperationsRepository(this._api, this._db, this._events);
  final PublicApiClient _api;
  final LocalDatabase _db;

  /// Posts anonymous counts: no cookie jar, account or device id.
  final Dio _events;

  Future<Map<String, dynamic>> fetch() => _api.get('app/operations');

  Future<void> report(String surface, String itemId, String event) async {
    await _events.post<Object?>(
      'app/operations/events',
      data: {
        'surface': surface,
        'itemId': itemId,
        'event': event,
        'platform': defaultTargetPlatform.name.toLowerCase(),
      },
    );
  }

  Future<Map<String, String>> readLocal() async {
    final rows = await _db.batch([
      const SqlStatement(
        "SELECT key, value FROM preferences WHERE key LIKE 'app.operations.%'",
        [],
        true,
      ),
    ]);
    return {
      for (final row in rows.single)
        (row['key'] as String).substring(15): row['value'] as String,
    };
  }

  Future<void> saveLocal(String key, String value) async {
    await _db.batch([
      SqlStatement(
        'INSERT INTO preferences(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
        ['app.operations.$key', value],
      ),
    ], write: true);
  }

  Future<File?> cachedSplash(Uri image, String? record) async {
    if (record == null) return null;
    final json = jsonDecode(record) as Map<String, dynamic>;
    if (json['url'] != image.toString()) return null;
    final name = json['file'] as String;
    if (!RegExp(r'^splash-\d+\.image$').hasMatch(name)) return null;
    final db = File(await resolvePersonalDatabasePath());
    final file = File('${db.parent.path}/$name');
    return await file.exists() ? file : null;
  }

  /// Download for the next launch, never delay entering the application.
  Future<String> cacheSplash(Uri uri, String? previous) async {
    if (await cachedSplash(uri, previous) != null) return previous!;
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final cancel = CancelToken();
    try {
      final response = await client.get<List<int>>(
        uri.toString(),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancel,
        onReceiveProgress: (received, _) {
          if (received > 8 * 1024 * 1024) cancel.cancel();
        },
      );
      final bytes = response.data!;
      if (bytes.length > 8 * 1024 * 1024 ||
          !(response.headers.value('content-type') ?? '').startsWith(
            'image/',
          )) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final db = File(await resolvePersonalDatabasePath());
      final name = 'splash-${DateTime.now().microsecondsSinceEpoch}.image';
      final file = File('${db.parent.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      final record = jsonEncode({'url': uri.toString(), 'file': name});
      try {
        await saveLocal('image', record);
      } catch (_) {
        await file.delete();
        rethrow;
      }
      if (previous != null) {
        final old = jsonDecode(previous) as Map<String, dynamic>;
        final oldName = old['file'];
        if (oldName is String &&
            RegExp(r'^splash-\d+\.image$').hasMatch(oldName)) {
          final oldFile = File('${db.parent.path}/$oldName');
          if (await oldFile.exists()) await oldFile.delete();
        }
      }
      return record;
    } finally {
      client.close(force: true);
    }
  }
}
