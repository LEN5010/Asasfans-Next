import 'package:flutter/material.dart';

import '../../../core/domain/bilibili_id.dart';
import 'creator_page.dart';

/// Root route keeps profile browsing independent of the shell's bottom bar.
Future<void> openCreatorPage(BuildContext context, String mid) async {
  if (!validBilibiliMid(mid) || CreatorRouteScope.of(context) == mid) return;
  await Navigator.of(
    context,
    rootNavigator: true,
  ).push<void>(MaterialPageRoute(builder: (_) => CreatorPage(mid: mid)));
}

class CreatorRouteScope extends InheritedWidget {
  const CreatorRouteScope({required this.mid, required super.child, super.key});
  final String mid;
  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CreatorRouteScope>()?.mid;
  @override
  bool updateShouldNotify(CreatorRouteScope oldWidget) => oldWidget.mid != mid;
}

class CreatorLink extends StatelessWidget {
  const CreatorLink({required this.mid, required this.child, super.key});
  final String? mid;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (mid == null ||
        !validBilibiliMid(mid!) ||
        CreatorRouteScope.of(context) == mid) {
      return child;
    }
    return Semantics(
      button: true,
      child: Tooltip(
        message: 'UP 主页',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openCreatorPage(context, mid!),
          child: child,
        ),
      ),
    );
  }
}
