import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/content/presentation/content_page.dart';
import '../../features/mine/presentation/mine_page.dart';
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
                  for (final entry in const [
                    ('saved', '收藏', Icons.bookmark_border),
                    ('history', '观看历史', Icons.history),
                    ('subscriptions', '订阅管理', Icons.person_add_alt),
                    ('reminders', '提醒', Icons.notifications_none),
                  ])
                    GoRoute(
                      path: entry.$1,
                      builder: (context, state) =>
                          PersonalSectionPage(title: entry.$2, icon: entry.$3),
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
