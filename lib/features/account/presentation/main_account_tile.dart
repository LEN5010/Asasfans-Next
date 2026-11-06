import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/main_account_providers.dart';

/// The settings row that opens the account page.
class MainAccountTile extends ConsumerWidget {
  const MainAccountTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(mainAccountControllerProvider);
    final user = account.session?.user;
    final unbound = user != null && user.email == null;
    final detail = account.loading
        ? null
        : user == null
        ? '未登录'
        : unbound
        ? '需要绑定邮箱'
        : user.username;
    return InkWell(
      onTap: () => context.go('/mine/settings/account'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const ToneBadge(icon: Icons.person_outline),
              const SizedBox(width: 14),
              Text('用户', style: theme.textTheme.bodyLarge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    detail ?? '',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unbound
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: unbound ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
