import 'package:flutter/material.dart';

import '../../../shared/widgets/media_cover.dart';
import '../domain/dynamic_repository.dart';

/// Only exact archive labels are replaced. Unrecognised tags stay readable text.
class DynamicRichText extends StatelessWidget {
  const DynamicRichText({
    super.key,
    required this.text,
    this.media = const [],
    this.maxLines,
    this.style,
    this.selectable = true,
  });
  final String text;
  final List<DynamicMedia> media;
  final int? maxLines;
  final TextStyle? style;

  /// A preview inside a tappable card must not select: a selection region
  /// wins the tap and the card would never open.
  final bool selectable;

  static final _tokens = RegExp(r'\[[^\]\n]{1,80}\]');
  static String stickerKey(String label) =>
      label.replaceAll(RegExp(r'^\[|\]$'), '').trim();
  static const _assets = {
    '心宜和思诺的交响乐谱_举高高': 'assets/stickers/lift.png',
    '心宜和思诺的交响乐谱_吃饭': 'assets/stickers/meal.png',
    '心宜和思诺的交响乐谱_晚安喵': 'assets/stickers/goodnight.png',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = {
      for (final item in media)
        if (item.kind == DynamicMediaKind.emoji &&
            item.url != null &&
            item.label.isNotEmpty)
          stickerKey(item.label): item.url!,
    };
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _tokens.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final label = match.group(0)!;
      final key = stickerKey(label);
      final url = emoji[key];
      final asset = _assets[key];
      if (url == null && asset == null) {
        spans.add(TextSpan(text: label));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: url != null
                    ? Image.network(
                        displayImageUri(url, width: 96).toString(),
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        semanticLabel: label,
                        errorBuilder: (_, _, _) => asset == null
                            ? const Icon(Icons.broken_image_outlined, size: 24)
                            : Image.asset(
                                asset,
                                width: 32,
                                height: 32,
                                semanticLabel: label,
                              ),
                      )
                    : Image.asset(
                        asset!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        semanticLabel: label,
                      ),
              ),
            ),
          ),
        );
      }
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    final rich = Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      style: style ?? Theme.of(context).textTheme.bodyLarge,
    );
    return selectable ? SelectionArea(child: rich) : rich;
  }
}
