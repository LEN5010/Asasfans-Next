import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_controls.dart';
import 'app_motion.dart';

/// A bounded choice strip with a discoverable, keyboard-accessible next action.
class HorizontalChoices extends StatefulWidget {
  const HorizontalChoices({super.key, required this.children});
  final List<Widget> children;
  @override
  State<HorizontalChoices> createState() => _HorizontalChoicesState();
}

class _HorizontalChoicesState extends State<HorizontalChoices> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final child in widget.children)
                Padding(padding: const EdgeInsets.only(right: 6), child: child),
            ],
          ),
        ),
      ),
      AppButton.icon(
        tooltip: '滚动筛选项',
        icon: const Icon(Icons.chevron_right),
        onPressed: () {
          if (!_scroll.hasClients) return;
          final p = _scroll.position;
          final target = p.pixels >= p.maxScrollExtent - 1
              ? 0.0
              : (p.pixels + p.viewportDimension * .7).clamp(
                  0.0,
                  p.maxScrollExtent,
                );
          if (MediaQuery.disableAnimationsOf(context)) {
            _scroll.jumpTo(target);
          } else {
            _scroll.animateTo(
              target,
              duration: appMotion(context, AppTokens.controlMotion),
              curve: Curves.easeOut,
            );
          }
        },
      ),
    ],
  );
}
