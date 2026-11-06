import 'dart:async';
import 'package:asasfans_next/features/account/application/main_account_controller.dart';
import 'package:asasfans_next/features/account/application/collection_sync_controller.dart';
import 'package:asasfans_next/features/account/data/main_account_api.dart';
import 'package:asasfans_next/features/account/domain/main_account.dart';
import 'package:asasfans_next/features/library/data/cloud_collections.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';
import '../helpers/sqlite_fixture.dart';

const session = MainSession(
  'token',
  MainUser('a', 'alice', email: 'alice@example.com'),
);
const unbound = MainSession('token', MainUser('a', 'alice'));
const item = ContentSnapshot(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '123',
  ),
  title: '作品',
  body: '',
  authorName: '作者',
);

class FakeMainApi implements MainAccountApi {
  bool expired = false;
  int revoked = 0;
  String? sentTo;
  MainSession issued = session;
  Completer<List<CloudFavorite>>? pull;
  @override
  Future<MainSession> login(String account, String password) async => issued;
  @override
  Future<MainSession> register(String username, String password) async =>
      unbound;
  @override
  Future<void> sendEmailCode(
    String token,
    String email, {
    String? currentPassword,
  }) async => sentTo = email;
  @override
  Future<String> verifyEmail(String token, String code) async {
    if (code != '123456') throw const MainAccountFailure('验证码不正确或已过期');
    return sentTo!;
  }

  @override
  Future<void> requestPasswordReset(String account) async {}
  @override
  Future<void> confirmPasswordReset(
    String account,
    String code,
    String newPassword,
  ) async {}
  @override
  Future<MainUser> me(String token) async {
    if (expired) throw const MainAccountFailure('过期', expired: true);
    return issued.user;
  }

  @override
  Future<void> revoke(String token) async {
    revoked++;
    if (expired) throw const MainAccountFailure('过期', expired: true);
  }

  @override
  Future<Set<String>> push(
    String token,
    List<Map<String, Object?>> ops,
  ) async => {};
  @override
  Future<List<CloudFavorite>> favorites(String token) async =>
      pull == null ? [] : await pull!.future;
}

void main() {
  test(
    'login imports visitor collections once and logout returns to visitor',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final local = SqliteLibraryRepository(db, backgroundDecoding: false);
      addTearDown(local.close);
      await local.setCollected(item, 'default', true);
      final api = FakeMainApi(), vault = MemoryMainAccountVault();
      final controller = MainAccountController(api, vault, db);
      addTearDown(controller.dispose);
      await controller.restore();
      var prompts = 0;
      Future<bool> choose(bool value) async {
        prompts++;
        return value;
      }

      expect(await controller.login('alice', 'pw', () => choose(true)), isTrue);
      expect(controller.session?.user.id, 'a');
      expect(vault.session?.token, 'token');
      expect((await CloudCollections(db, 'a').pending()).single['op'], 'add');
      expect(await controller.logout(), isTrue);
      expect(controller.session, isNull);
      expect(vault.session, isNull);
      expect(api.revoked, 1);
      await controller.login('alice', 'pw', () => choose(false));
      expect(prompts, 1);
    },
  );
  test(
    'a new account keeps the visitor library until its email is verified',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final api = FakeMainApi(), vault = MemoryMainAccountVault();
      final controller = MainAccountController(api, vault, db);
      addTearDown(controller.dispose);
      await controller.restore();
      expect(
        await controller.register('alice', 'alice@example.com', 'pw'),
        isTrue,
      );
      expect(api.sentTo, 'alice@example.com');
      expect(controller.session?.user.email, isNull);
      expect(await CloudCollections(db, 'a').initialized(), isFalse);
      expect(await controller.verifyEmail('000000', () async => true), isFalse);
      expect(controller.error, contains('验证码'));
      expect(await controller.verifyEmail('123456', () async => false), isTrue);
      expect(controller.session?.user.email, 'alice@example.com');
      expect(vault.session?.user.email, 'alice@example.com');
      expect(await CloudCollections(db, 'a').initialized(), isTrue);
    },
  );
  test('401 during sync removes credentials and selects visitor', () async {
    final db = MemoryLocalDatabase();
    addTearDown(db.close);
    await CloudCollections(db, 'a').initialize(importLocal: false);
    final api = FakeMainApi()..expired = true,
        vault = MemoryMainAccountVault()..session = session;
    final controller = MainAccountController(api, vault, db);
    addTearDown(controller.dispose);
    await controller.restore();
    final library = SqliteLibraryRepository(
      db,
      owner: 'a',
      backgroundDecoding: false,
    );
    addTearDown(library.close);
    final sync = CollectionSyncController(controller, db, library);
    addTearDown(sync.dispose);
    await sync.sync();
    expect(controller.session, isNull);
    expect(vault.session, isNull);
    expect(controller.error, contains('重新登录'));
  });
  test(
    'a response from the previous account cannot modify collections after logout',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      await CloudCollections(db, 'a').initialize(importLocal: false);
      final api = FakeMainApi()..pull = Completer<List<CloudFavorite>>(),
          vault = MemoryMainAccountVault()..session = session;
      final controller = MainAccountController(api, vault, db);
      addTearDown(controller.dispose);
      await controller.restore();
      final library = SqliteLibraryRepository(
        db,
        owner: 'a',
        backgroundDecoding: false,
      );
      addTearDown(library.close);
      final sync = CollectionSyncController(controller, db, library);
      addTearDown(sync.dispose);
      final work = sync.sync();
      await Future<void>.delayed(Duration.zero);
      await controller.logout();
      api.pull!.complete([const CloudFavorite('bili:123', 1, item)]);
      await work;
      expect((await library.itemState(item.identity)).folderIds, isEmpty);
    },
  );
}
