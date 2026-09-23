import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Soft A-SOUL support-colour light behind the main pages, so floating glass
/// has colour to refract even where no content passes beneath it. Content
/// cards stay on their own solid surfaces above it.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({required this.child, super.key});
  final Widget child;

  static const _glows = [
    ('A-SOUL', Alignment(-1.1, -1.1), 1.0),
    ('嘉然', Alignment(1.1, -0.9), 1.0),
    ('乃琳', Alignment(-1.0, 1.1), .7),
    ('思诺', Alignment(1.1, 1.0), .6),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = theme.brightness == Brightness.dark ? .16 : .24;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final (member, center, weight) in _glows)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: center,
                        radius: 1.1,
                        colors: [
                          AppTheme.memberColors[member]!.withValues(
                            alpha: strength * weight,
                          ),
                          AppTheme.memberColors[member]!.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
