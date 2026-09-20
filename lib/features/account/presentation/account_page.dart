import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../library/presentation/library_common.dart';
import '../application/account_controller.dart';
import '../application/account_providers.dart';
import '../domain/bili_account.dart';
import 'web_login_page.dart';

String accountModeLabel(AccountMode mode) => switch (mode) {
  AccountMode.loading => '正在读取账号',
  AccountMode.guest => '未登录',
  AccountMode.unverified => '待验证',
  AccountMode.verified => '已登录',
  AccountMode.expired => '登录已失效',
  AccountMode.storageError => '账号暂不可用',
  AccountMode.logoutPending => '退出清理未完成',
};
String accountFailureMessage(Object failure) => failure is ApiFailure
    ? failure.message
    : failure is AccountFailure
    ? failure.message
    : '账号暂不可用';

class AccountSummaryTile extends ConsumerWidget {
  const AccountSummaryTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountControllerProvider);
    return ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(account.profile?.name ?? 'Bilibili 账号'),
      subtitle: Text(accountModeLabel(account.mode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const AccountPage())),
    );
  }
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  late final AccountController _account = ref.read(accountControllerProvider);
  @override
  void dispose() {
    if (_account.loginActive) {
      final generation = _account.loginGeneration;
      unawaited(
        Future<void>.microtask(
          () => _account.cancelLogin(generation: generation),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _web() async {
    final generation = await _account.startWeb();
    if (generation == null) return;
    if (!mounted) {
      await _account.cancelLogin(generation: generation);
      return;
    }
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WebLoginPage(generation: generation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountControllerProvider);
    final profile = account.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Bilibili 账号')),
      body: LibraryBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (account.busy || account.mode == AccountMode.loading)
              const LinearProgressIndicator(),
            if (profile != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 32,
                  foregroundImage: profile.avatar == null
                      ? null
                      : ResizeImage(
                          NetworkImage(profile.avatar.toString()),
                          width: 160,
                        ),
                  onForegroundImageError: profile.avatar == null
                      ? null
                      : (_, _) {},
                  child: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
              Text('UID ${profile.mid}'),
              const SizedBox(height: 12),
            ],
            Text(
              accountModeLabel(account.mode),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (account.failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(accountFailureMessage(account.failure!)),
              ),
            if (account.mode == AccountMode.storageError)
              OutlinedButton(
                onPressed: account.busy ? null : account.restore,
                child: const Text('重试读取账号'),
              ),
            if (account.mode == AccountMode.storageError)
              TextButton(
                onPressed: account.busy
                    ? null
                    : () async {
                        if (await confirmLibraryAction(context, '清除本地登录信息？') &&
                            mounted) {
                          await account.logout();
                        }
                      },
                child: const Text('清除本地登录'),
              ),
            if (account.mode == AccountMode.logoutPending)
              OutlinedButton(
                onPressed: account.busy ? null : account.logout,
                child: const Text('重试退出清理'),
              ),
            if (profile != null)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  RetryButton(
                    failure: account.failure is ApiFailure
                        ? account.failure as ApiFailure
                        : null,
                    onRetry: account.busy ? null : account.verifySession,
                    label: '验证登录',
                  ),
                  OutlinedButton(
                    onPressed: account.busy
                        ? null
                        : () async {
                            if (await confirmLibraryAction(
                                  context,
                                  '退出本地 B 站账号？',
                                ) &&
                                mounted) {
                              await account.logout();
                            }
                          },
                    child: const Text('退出登录'),
                  ),
                ],
              ),
            if (account.mode == AccountMode.guest) ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (account.cookies.supportsWebLogin)
                    FilledButton.icon(
                      onPressed: account.busy ? null : _web,
                      icon: const Icon(Icons.language),
                      label: const Text('网页登录'),
                    ),
                  OutlinedButton.icon(
                    onPressed: account.busy ? null : account.startQr,
                    icon: const Icon(Icons.qr_code),
                    label: Text(account.ticket == null ? '扫码登录' : '更换二维码'),
                  ),
                  if (account.loginActive)
                    TextButton(
                      onPressed: account.busy ? null : account.cancelLogin,
                      child: const Text('取消登录'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (account.ticket != null &&
                  account.loginPhase != AccountLoginPhase.expired)
                Center(
                  child: Semantics(
                    label: 'B 站登录二维码',
                    image: true,
                    child: ColoredBox(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: account.ticket!.url.toString(),
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              if (account.loginPhase != AccountLoginPhase.none)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(switch (account.loginPhase) {
                    AccountLoginPhase.creating => '正在获取二维码',
                    AccountLoginPhase.waiting => '请用 B 站客户端扫码',
                    AccountLoginPhase.scanned => '请在 B 站确认登录',
                    AccountLoginPhase.checking => '正在验证登录',
                    AccountLoginPhase.expired => '二维码已失效',
                    AccountLoginPhase.failed => '登录未完成',
                    AccountLoginPhase.web => '请完成网页登录',
                    AccountLoginPhase.none => '',
                  }, textAlign: TextAlign.center),
                ),
              if (account.loginPhase == AccountLoginPhase.creating ||
                  account.loginPhase == AccountLoginPhase.checking)
                const Center(child: CircularProgressIndicator()),
              if (account.loginPhase == AccountLoginPhase.failed)
                RetryButton(
                  failure: account.failure is ApiFailure
                      ? account.failure as ApiFailure
                      : null,
                  onRetry: account.busy ? null : account.retryLogin,
                  label: '重试登录',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
