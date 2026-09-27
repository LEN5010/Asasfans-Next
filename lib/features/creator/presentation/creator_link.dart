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

/// Opens a creator's Bilibili space. With a [minHeight] the whole band is
/// the target while the words stay their size, centred in it; the band is
/// the link's own space in the layout, so it never lies over the work's tap
/// or a neighbouring button.
///
/// The link answers as a link: under the pointer its words are underlined
/// (no grey block over the band), keyboard focus draws a ring, and the
/// tooltip waits a moment, so passing over a feed does not raise one
/// bubble per name.
class CreatorLink extends StatefulWidget {
  const CreatorLink({
    required this.mid,
    required this.child,
    this.minHeight = 0,
    super.key,
  });
  final String? mid;
  final Widget child;
  final double minHeight;

  @override
  State<CreatorLink> createState() => _CreatorLinkState();
}

class _CreatorLinkState extends State<CreatorLink> {
  bool _hovered = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final mid = widget.mid;
    Widget content = widget.minHeight > 0
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: widget.child,
            ),
          )
        : widget.child;
    if (mid == null || !validBilibiliMid(mid)) return content;
    if (_hovered) {
      content = DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.underline),
        child: content,
      );
    }
    final radius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      child: Tooltip(
        message: '在 B 站打开 UP 主页',
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          borderRadius: radius,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          onTap: () => openCreatorPage(context, mid),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: _focused
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
