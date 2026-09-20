import '../../features/rules/presentation/rules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/backup/presentation/backup_page.dart';
import '../../features/content/presentation/content_page.dart';
import '../../features/mine/presentation/mine_page.dart';
import '../../features/library/presentation/library_pages.dart';
import '../../features/library/presentation/playback_pages.dart';
import '../../features/library/presentation/calendar_follows.dart';
import '../../features/today/presentation/today_page.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/content',
                builder: (context, state) => const ContentPage(),
                routes: [
                  GoRoute(
                    path: ':channel',
                    redirect: (context, state) =>
                        const {
                          'fanart',
                          'clips',
                          'latest',
                          'subscriptions',
                          'replays',
                          'dynamics',
                        }.contains(state.pathParameters['channel'])
                        ? null
                        : '/content',
                    builder: (context, state) =>
                        ContentPage(channel: state.pathParameters['channel']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                builder: (context, state) => const MinePage(),
                routes: [
                  GoRoute(
                    path: 'saved',
                    builder: (_, _) => const CollectionsPage(),
                    routes: [
                      GoRoute(
                        path: ':folder',
                        builder: (_, state) => CollectionPage(
                          folderId: state.pathParameters['folder']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'later',
                    builder: (_, _) => const WatchLaterPage(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (_, _) => const LibraryHistoryPage(),
                  ),
                  GoRoute(
                    path: 'continue',
                    builder: (_, _) => const ContinueWatchingPage(),
                  ),
                  GoRoute(
                    path: 'bookmarks',
                    builder: (_, _) => const BookmarksPage(),
                  ),
                  GoRoute(
                    path: 'subscriptions',
                    builder: (_, _) => const SubscriptionsPage(),
                  ),
                  GoRoute(
                    path: 'calendar-follows',
                    builder: (_, _) => const CalendarFollowsPage(),
                  ),
                  GoRoute(path: 'rules', builder: (_, _) => const RulesPage()),
                  GoRoute(
                    path: 'backup',
                    builder: (_, _) => const BackupPage(),
                  ),
                  GoRoute(
                    path: 'reminders',
                    builder: (_, _) => const PersonalSectionPage(
                      title: '提醒',
                      icon: Icons.notifications_none,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/today'),
          child: const Text('返回首页'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
