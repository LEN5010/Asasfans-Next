import '../../features/rules/presentation/rules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/backup/presentation/backup_page.dart';
import '../../features/content/application/content_providers.dart';
import '../../features/content/domain/community_video_repository.dart';
import '../../features/content/presentation/content_page.dart';
import '../../features/mine/presentation/mine_page.dart';
import '../../features/library/presentation/library_pages.dart';
import '../../features/library/presentation/playback_pages.dart';
import '../../features/library/presentation/calendar_follows.dart';
import '../../features/handoff/presentation/return_restorer.dart';
import '../../features/today/presentation/today_page.dart';
import '../../features/updates/presentation/updates_page.dart';
import '../../shared/widgets/app_page_bar.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      StatefulShellRoute(
        navigatorContainerBuilder: (context, shell, children) =>
            FadeThroughBranches(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        builder: (context, state, navigationShell) =>
            // Wraps the shell so a return lands before any branch is chosen.
            ReturnRestorer(
              child: AppShell(
                navigationShell: navigationShell,
                isTabRoot: const {
                  '/today',
                  '/calendar',
                  '/mine',
                  '/content',
                  '/content/videos',
                  '/content/fanart',
                  '/content/dynamics',
                  '/content/novels',
                }.contains(state.uri.path),
              ),
            ),
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
              // Channels are one page updated in place: the same page key
              // with no route transition, so switching only slides the feed.
              GoRoute(
                path: '/content',
                pageBuilder: (context, state) => const NoTransitionPage(
                  key: ValueKey('content'),
                  child: ContentPage(channel: 'videos'),
                ),
              ),
              GoRoute(
                path: '/content/:channel',
                redirect: (context, state) {
                  final slug = state.pathParameters['channel'];
                  if (ContentChannel.values.any((c) => c.slug == slug)) {
                    return null;
                  }
                  // An old video channel keeps its kind as a filter.
                  if (CommunityChannel.values.any((c) => c.name == slug)) {
                    return '/content/videos?kind=$slug';
                  }
                  return '/content';
                },
                pageBuilder: (context, state) => NoTransitionPage(
                  key: const ValueKey('content'),
                  child: ContentPage(
                    channel: state.pathParameters['channel']!,
                    videoKind: state.uri.queryParameters['kind'],
                  ),
                ),
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
                  GoRoute(
                    path: 'updates',
                    builder: (_, _) => const UpdatesPage(),
                  ),
                  GoRoute(path: 'rules', builder: (_, _) => const RulesPage()),
                  GoRoute(
                    path: 'backup',
                    builder: (_, _) => const BackupPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: const AppPageBar(title: Text('页面不存在')),
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
