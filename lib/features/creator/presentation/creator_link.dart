import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/domain/bilibili_id.dart';

/// Creator profiles live on Bilibili; the app hands them off like videos.
Future<void> openCreatorPage(BuildContext context, String mid) async {
  if (!validBilibiliMid(mid)) return;
  final opened = await ProviderScope.containerOf(context, listen: false)
      .read(externalLinkServiceProvider)
      .open(Uri.https('space.bilibili.com', '/$mid'));
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
  }
}

class CreatorLink extends StatelessWidget {
  const CreatorLink({required this.mid, required this.child, super.key});
  final String? mid;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (mid == null || !validBilibiliMid(mid!)) return child;
    return Semantics(
      button: true,
      child: Tooltip(
        message: '在 B 站打开 UP 主页',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openCreatorPage(context, mid!),
          child: child,
        ),
      ),
    );
  }
}
