import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/main_account_providers.dart';

/// The account at the top of 我的: who is signed in and whether the
/// collection is in sync, or a way to sign in.
class MainAccountCard extends ConsumerWidget {
  const MainAccountCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final account = ref.watch(mainAccountControllerProvider);
    final sync = ref.watch(collectionSyncProvider);
    final user = account.session?.user;
    final unbound = user != null && user.email == null;
    void open() => context.go('/mine/account');
    final detail = user == null
        ? null
        : unbound
        ? '需要绑定邮箱'
        : sync?.busy == true
        ? '正在同步收藏…'
        : sync?.error ?? user.email;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              AccountAvatar(name: user?.username, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.loading ? '' : user?.username ?? '未登录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unbound || sync?.error != null
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: unbound ? FontWeight.w600 : null,
                        ),
                      ),
                  ],
                ),
              ),
              if (user == null && !account.loading)
                AppButton(
                  selected: true,
                  onPressed: open,
                  child: const Text('登录 / 注册'),
                )
              else
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round mark for the account: the name's first character on the
/// support colour, or a person outline while signed out.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, this.name, this.size = 48});
  final String? name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = MemberTone.of('嘉然', theme.brightness);
    final initial = name?.characters.firstOrNull?.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: initial == null
              ? theme.colorScheme.surfaceContainerHigh
              : tone.wash,
        ),
        child: initial == null
            ? Icon(
                Icons.person_outline,
                size: size * .5,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : Text(
                initial,
                style: TextStyle(
                  fontSize: size * .42,
                  fontWeight: FontWeight.w800,
                  color: tone.text,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
