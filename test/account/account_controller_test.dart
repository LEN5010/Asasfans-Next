import 'package:asasfans_next/features/account/application/account_controller.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';

class _OrderedVault extends MemoryAccountVault {
  _OrderedVault(this.intent);
  final MemoryLogoutIntent intent;
  bool? pendingAtClear;
  @override
  Future<void> clear() {
    pendingAtClear = intent.value;
    return super.clear();
  }
}

void main() {
  late MemoryAccountVault vault;
  late MemoryLogoutIntent intent;
  late MemoryLoginCookies cookies;
  late AccountController controller;
  setUp(() {
    intent = MemoryLogoutIntent();
    vault = _OrderedVault(intent);
    cookies = MemoryLoginCookies();
    controller = AccountController(vault, intent, cookies);
  });
  tearDown(() => controller.dispose());

  test('nothing stored offers nothing to clear', () async {
    await controller.restore();
    expect(controller.mode, AccountMode.none);
    expect(controller.hasLocalLogin, isFalse);
  });

  test('a stored session is only reported until the user clears it', () async {
    vault.value = true;
    await controller.restore();
    expect(controller.mode, AccountMode.stored);
    expect(controller.hasLocalLogin, isTrue);
    expect(vault.clears, 0);
    expect(cookies.clears, 0);
    await controller.clear();
    expect((vault as _OrderedVault).pendingAtClear, isTrue);
    expect(vault.value, isFalse);
    expect(cookies.clears, 1);
    expect(intent.value, isFalse);
    expect(controller.mode, AccountMode.none);
    expect(controller.hasLocalLogin, isFalse);
  });

  test(
    'a pending cleanup survives restart without reading the vault',
    () async {
      vault.value = true;
      intent.value = true;
      await controller.restore();
      expect(vault.reads, 0);
      expect(controller.mode, AccountMode.logoutPending);
      expect(controller.hasLocalLogin, isTrue);
      await controller.clear();
      expect(controller.mode, AccountMode.none);
      expect(vault.value, isFalse);
      expect(intent.value, isFalse);
    },
  );

  test(
    'delete and browser failures do not claim success; retry completes',
    () async {
      vault.value = true;
      await controller.restore();
      vault.clearError = const AccountFailure(AccountFailureKind.cleanup);
      await controller.clear();
      expect(controller.mode, AccountMode.logoutPending);
      expect(controller.failure?.kind, AccountFailureKind.cleanup);
      expect(intent.value, isTrue);
      vault.clearError = null;
      cookies.clearError = const AccountFailure(AccountFailureKind.cleanup);
      await controller.clear();
      expect(vault.value, isFalse);
      expect(controller.mode, AccountMode.logoutPending);
      expect(intent.value, isTrue);
      cookies.clearError = null;
      await controller.clear();
      expect(controller.mode, AccountMode.none);
      expect(controller.failure, isNull);
      expect(intent.value, isFalse);
    },
  );

  test('nothing is deleted when the cleanup intent cannot commit', () async {
    vault.value = true;
    await controller.restore();
    intent.error = const AccountFailure(AccountFailureKind.storage);
    await controller.clear();
    expect(vault.clears, 0);
    expect(vault.value, isTrue);
    expect(controller.mode, AccountMode.stored);
    expect(controller.failure?.kind, AccountFailureKind.storage);
    intent.error = null;
    await controller.clear();
    expect(controller.mode, AccountMode.none);
  });

  test('an unreadable vault can still be cleared', () async {
    vault.readError = const AccountFailure(AccountFailureKind.storage);
    await controller.restore();
    expect(controller.mode, AccountMode.storageError);
    expect(controller.hasLocalLogin, isTrue);
    await controller.clear();
    expect(controller.mode, AccountMode.none);
    expect(vault.clears, 1);
  });
}
