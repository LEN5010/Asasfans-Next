import 'package:flutter/material.dart';

import 'glass/app_glass_surface.dart';

/// Shared secondary-page chrome. Reading content below remains opaque.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({super.key, required this.title, this.actions});
  final Widget title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    radius: 0,
    child: AppBar(
      title: title,
      actions: actions,
      backgroundColor: Colors.transparent,
    ),
  );
}
