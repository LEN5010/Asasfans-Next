import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/feature_pending.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in const [
          ('收藏', 'saved', Icons.bookmark_border),
          ('观看历史', 'history', Icons.history),
          ('订阅管理', 'subscriptions', Icons.person_add_alt),
          ('提醒', 'reminders', Icons.notifications_none),
        ])
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(entry.$3),
              title: Text(entry.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/mine/${entry.$2}'),
            ),
          ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Asasfans Next',
          ),
        ),
      ],
    ),
  );
}

class PersonalSectionPage extends StatelessWidget {
  const PersonalSectionPage({
    required this.title,
    required this.icon,
    super.key,
  });
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FeaturePending(icon: icon),
  );
}
