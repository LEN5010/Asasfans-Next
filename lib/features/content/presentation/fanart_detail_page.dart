import 'dart:math' as math;

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../rules/application/feed_visibility.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';

import '../../handoff/domain/return_context.dart';
import '../../handoff/presentation/watch_on_bilibili.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/domain/content_identity.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../creator/presentation/creator_link.dart';
import '../domain/fanart_repository.dart';
import '../../../shared/widgets/media_image_policy.dart';
import 'fanart_image_viewer.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/history_recorder.dart';
import '../../library/presentation/library_common.dart';

/// Opens a fanart item where it can be seen: a video on Bilibili, anything
/// else in the app's own detail page.
void openFanart(
  BuildContext context,
  WidgetRef ref,
  FanartItem item, {
  ReturnTarget returnTo = ReturnTarget.today,
  String? channel,
  Map<String, Object?>? query,
  ReturnAnchor? anchor,
  Object? heroTag,
}) {
  if (item.contentType == FanartContentType.video && item.sourceUrl != null) {
    openContentSource(
      context,
      ref,
      ContentSnapshots.fanart(item),
      url: item.sourceUrl,
      returnTo: returnTo,
      channel: channel,
      query: query,
      anchor: anchor,
    );
    return;
  }
  // The detail page is a stop on the way, not a new origin: a trip out from
  // it returns to the list the work was picked from.
  final origin = WatchOrigin(
    target: returnTo,
    channel: channel,
    query: query,
    anchorOf: anchor == null ? null : () => anchor,
  );
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          FanartDetailPage(item: item, origin: origin, heroTag: heroTag),
    ),
  );
}

/// Reading view for one fanart post.
///
/// The item is handed in from the list rather than re-fetched, so opening a
/// detail costs no extra request against the shared rate limit and returning
/// keeps the list exactly where it was.
class FanartDetailPage extends ConsumerWidget {
  const FanartDetailPage({
    required this.item,
    this.origin = WatchOrigin.today,
    this.heroTag,
    super.key,
  });

  final FanartItem item;

  /// The tile's tag, when opened from a tile that has one.
  final Object? heroTag;

  /// Where the work was picked from, handed on to any trip out of the page.
  final WatchOrigin origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = item.text.trim();
    return HistoryRecorder(
      item: ContentSnapshots.fanart(item),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppPageBar(
          title: Text(item.authorName.isEmpty ? '二创详情' : item.authorName),
          actions: [
            ContentActionsButton(
              item: ContentSnapshots.fanart(item),
              ruleSubject: RuleSubjects.fanart(item),
            ),
            if (item.sourceUrl != null)
              AppButton.icon(
                tooltip: '打开原动态',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => openContentSource(
                  context,
                  ref,
                  ContentSnapshots.fanart(item),
                  url: item.sourceUrl,
                  returnTo: origin.target,
                  channel: origin.channel,
                  query: origin.query,
                  anchor: origin.anchorOf?.call(),
                ),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final info = <Widget>[
              _AuthorRow(item: item),
              const SizedBox(height: 16),
              if (text.isNotEmpty)
                SelectableText(text, style: theme.textTheme.bodyLarge),
              if (item.images.isEmpty && text.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('这条动态没有可显示的正文或图片')),
                ),
              _MetaRow(item: item),
            ];
            final oneColumn = constraints.maxWidth < 1000;
            final images = <Widget>[
              for (var index = 0; index < item.images.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DetailImage(
                    item: item,
                    index: index,
                    // The first image leads the page, so it may not push the
                    // author and the words far down.
                    cap: oneColumn && index == 0
                        ? math.max(240, constraints.maxHeight * .55)
                        : null,
                    heroTag: index == 0 ? heroTag : null,
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FanartImageViewer(
                              images: item.images,
                              initial: index,
                            ),
                          ),
                        ),
                  ),
                ),
            ];
            if (constraints.maxWidth >= 1000 && item.images.isNotEmpty) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      key: const ValueKey('fanart-detail-gallery'),
                      padding: pageInsets(context, horizontal: 24),
                      children: images,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: (constraints.maxWidth * .34).clamp(340, 440),
                    child: ListView(
                      key: const ValueKey('fanart-detail-info'),
                      padding: pageInsets(context, horizontal: 20),
                      children: info,
                    ),
                  ),
                ],
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                // The work leads: its first image, then who made it and
                // what they wrote, then the rest of the set.
                child: ListView(
                  padding: pageInsets(context),
                  children: [
                    ...images.take(1),
                    if (images.isNotEmpty) const SizedBox(height: 4),
                    ...info,
                    if (images.length > 1) const SizedBox(height: 16),
                    ...images.skip(1),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthorRow extends ConsumerWidget {
  const _AuthorRow({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mid =
        item.identity.source != ContentSource.doubanTopic &&
            validBilibiliMid(item.authorUid)
        ? item.authorUid
        : null;
    return Row(
      children: [
        CreatorLink(
          mid: mid,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundImage: item.authorAvatarUrl == null
                ? null
                : MediaImagePolicy.preview(
                    item.authorAvatarUrl!,
                    logicalWidth: 40,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
            child: Text(
              item.authorName.isEmpty ? '?' : item.authorName.characters.first,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CreatorLink(
            mid: mid,
            child: Text(
              item.authorName.isEmpty ? '未知作者' : item.authorName,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (mid != null || item.authorSpaceUrl != null)
          AppButton(
            onPressed: mid != null
                ? () => openCreatorPage(context, mid)
                : () => ref
                      .read(externalLinkServiceProvider)
                      .open(item.authorSpaceUrl!),
            child: const Text('作者主页'),
          ),
      ],
    );
  }
}

/// Long vertical artwork is common here, so the image keeps its aspect ratio
/// instead of being cropped into a fixed box.
///
/// With a [cap] (the first image of a one-column detail) a picture taller
/// than the cap shows its top as a preview and says so, with a way to the
/// whole of it; the author and the words then stay near the first screen.
/// The ratio comes from the preview the page decodes anyway, never from an
/// extra download.
class _DetailImage extends StatefulWidget {
  const _DetailImage({
    required this.item,
    required this.index,
    required this.onTap,
    this.cap,
    this.heroTag,
  });

  final FanartItem item;
  final int index;
  final VoidCallback onTap;
  final double? cap;
  final Object? heroTag;

  @override
  State<_DetailImage> createState() => _DetailImageState();
}

class _DetailImageState extends State<_DetailImage> {
  /// How far past the cap a picture must reach to count as long.
  static const _longFactor = 1.4;

  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, synchronous) {
    final ratio = info.image.width / info.image.height;
    // The listener holds its own handle to the image; only the ratio is
    // kept, so the handle is released at once.
    info.dispose();
    if (!mounted || ratio == _ratio) return;
    // A cached preview answers during this widget's own build (from
    // _watch): the ratio is then simply read by that build.
    if (synchronous) {
      _ratio = ratio;
    } else {
      setState(() => _ratio = ratio);
    }
  }, onError: (_, _) {});

  /// Width over height, once the preview has decoded.
  double? _ratio;

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  void _watch(ImageProvider provider) {
    if (widget.cap == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // A preview sized to the column; tapping opens the original.
        final provider = MediaImagePolicy.preview(
          widget.item.images[widget.index],
          logicalWidth: constraints.maxWidth,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        _watch(provider);
        final cap = widget.cap;
        final ratio = _ratio;
        // Only long art is cut: a picture that overshoots the cap by a
        // little (an ordinary portrait) is shown whole rather than trimmed
        // by a few pixels and called long.
        final capped =
            cap != null &&
            ratio != null &&
            constraints.maxWidth / ratio > cap * _longFactor;
        Widget image = Image(
          image: provider,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          width: double.infinity,
          height: capped ? cap : null,
          errorBuilder: (context, error, stack) => Container(
            height: 160,
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text(
              '图片加载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(
                  height: 160,
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        );
        if (capped) {
          image = Stack(
            children: [
              image,
              // The cut is said, not hidden: a fade and a way to the rest.
              Positioned.fill(
                top: cap * .7,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surface.withValues(alpha: 0),
                          theme.colorScheme.surface.withValues(alpha: .85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: AppButton.withIcon(
                    filled: true,
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.unfold_more, size: 18),
                    label: const Text('看完整长图'),
                  ),
                ),
              ),
            ],
          );
        }
        Widget framed = ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: image,
        );
        if (widget.heroTag case final tag?) {
          framed = HeroMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: Hero(tag: tag, child: framed),
          );
        }
        return GestureDetector(onTap: widget.onTap, child: framed);
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = <String>[
      item.category.wire,
      for (final tag in item.characterTags) tag.wire,
      if (item.viewCount != null) '播放 ${item.viewCount}',
      if (item.favoriteCount != null) '收藏 ${item.favoriteCount}',
    ];
    if (item.images.length > 1) labels.add('${item.images.length} 张 · 点按看原图');
    if (labels.isEmpty) return const SizedBox.shrink();
    // One quiet line of facts, not a chip for each.
    final style = theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        runSpacing: 4,
        children: [
          for (final (index, label) in labels.indexed) ...[
            if (index > 0) Text('  ·  ', style: style),
            Text(label, style: style),
          ],
        ],
      ),
    );
  }
}
