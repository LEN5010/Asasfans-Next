import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/library_common.dart';
import '../application/account_controller.dart';
import '../application/account_providers.dart';

/// The one account action left: removing a sign-in an earlier build stored.
class LocalLoginCleanupTile extends ConsumerWidget {
  const LocalLoginCleanupTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountControllerProvider);
    return ListTile(
      leading: const Icon(Icons.no_accounts_outlined),
      title: const Text('清除本地 B 站登录信息'),
      subtitle: Text(
        account.failure?.message ??
            (account.mode == AccountMode.logoutPending
                ? '上次清除未完成，请重试'
                : '应用已不再使用 B 站登录，旧版本留下的登录信息可以清除'),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      enabled: !account.busy,
      trailing: account.busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () async {
        if (await confirmLibraryAction(
          context,
          '清除本地 B 站登录信息？',
          body: '将删除本机保存的 B 站登录凭据和登录页面留下的 Cookie。',
        )) {
          await account.clear();
        }
      },
    );
  }
}
