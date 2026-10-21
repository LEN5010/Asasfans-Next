import 'dart:io';

import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/operations/application/operations_controller.dart';
import 'package:asasfans_next/features/operations/data/operations_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Map<String, dynamic> emptyOperations() => {
  'campaigns': <Map<String, dynamic>>[],
  'announcements': <Map<String, dynamic>>[],
  'updates': <Map<String, dynamic>>[],
  'support': {
    'feedbackUrl': 'https://example.test/feedback',
    'contactUrl': null,
    'helpUrl': null,
  },
};

class OperationsFixture extends OperationsRepository {
  OperationsFixture(LocalDatabase db, {Map<String, dynamic>? value})
    : value = value ?? emptyOperations(),
      super(PublicApiClient(Dio()), db, Dio());
  Map<String, dynamic> value;

  /// Reported counts as `surface:itemId:event`.
  final events = <String>[];
  bool offline = false;
  bool failCacheWrites = false;
  bool failSeenWrites = false;
  File? splashFile;
  @override
  Future<File?> cachedSplash(Uri image, String? record) async => splashFile;
  @override
  Future<String> cacheSplash(Uri image, String? previous) async => 'fixture';
  @override
  Future<void> report(String surface, String itemId, String event) async =>
      events.add('$surface:$itemId:$event');
  @override
  Future<void> saveLocal(String key, String value) {
    if (failCacheWrites && key == 'cache') {
      throw StateError('cache unavailable');
    }
    if (failSeenWrites && key == 'updates') {
      throw StateError('mark unavailable');
    }
    return super.saveLocal(key, value);
  }

  @override
  Future<Map<String, dynamic>> fetch() async {
    if (offline) throw StateError('offline');
    return value;
  }
}

Override offlineOperations() => operationsRepositoryProvider.overrideWith(
  (ref) => OperationsFixture(ref.watch(localDatabaseProvider)),
);
