import 'package:flutter/material.dart';

/// Content-first neutral canvas. Navigation samples actual content, not four
/// decorative full-window colour fields created solely to feed glass effects.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: child,
  );
}
