import 'dart:async';
import 'package:asasfans_next/features/account/application/account_controller.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryAccountVault implements BiliCredentialVault {
  bool value = false;
  Object? readError, clearError;
  int reads = 0, clears = 0;
  @override
  Future<bool> stored() async {
    reads++;
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (clearError != null) throw clearError!;
    value = false;
  }
}

class MemoryLogoutIntent implements LogoutIntentStore {
  bool value = false;
  Object? error;
  @override
  Future<bool> pending() async {
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<void> setPending(bool pending) async {
    if (error != null) throw error!;
    value = pending;
  }
}

class MemoryLoginCookies implements BiliLoginCookies {
  Object? clearError;
  int clears = 0;
  @override
  Future<void> clear() async {
    clears++;
    if (clearError != null) throw clearError!;
  }
}

Override offlineAccount({MemoryAccountVault? vault}) =>
    accountControllerProvider.overrideWith((ref) {
      final controller = AccountController(
        vault ?? MemoryAccountVault(),
        MemoryLogoutIntent(),
        MemoryLoginCookies(),
      );
      unawaited(controller.restore());
      return controller;
    });
