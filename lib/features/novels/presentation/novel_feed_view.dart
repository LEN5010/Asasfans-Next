import 'package:flutter/material.dart';

import '../../../shared/widgets/feed_scroll_view.dart';

/// Read-only novels from the dynamics archive.
class NovelFeedView extends StatelessWidget {
  const NovelFeedView({super.key});

  @override
  Widget build(BuildContext context) =>
      const FeedMessage(icon: Icons.menu_book_outlined, text: '小说正在接入');
}
