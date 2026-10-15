import 'dart:math' as math;

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/member_tone.dart';
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
///
/// The work leads: its first picture large, then who made it and what they
/// wrote, then the rest of the set as a grid. The two ways on — the
/// originals and the post at its source — are named buttons on a bar that
/// stays in reach, not icons in the corner.
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
    final text = item.text.trim();
    void openViewer(int index) =>
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => FanartImageViewer(
              images: item.images,
              initial: index,
              onOpenOriginal: (uri) async {
                final opened = await ref
                    .read(externalLinkServiceProvider)
                    .open(uri);
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('无法打开原图')));
                }
              },
            ),
          ),
        );
    final actions = _ActionBar(
      item: item,
      onViewer: item.images.isEmpty ? null : () => openViewer(0),
      onSource: item.sourceUrl == null
          ? null
          : () => openContentSource(
              context,
              ref,
              ContentSnapshots.fanart(item),
              url: item.sourceUrl,
              returnTo: origin.target,
              channel: origin.channel,
              query: origin.query,
              anchor: origin.anchorOf?.call(),
            ),
    );
    final hasActions = item.images.isNotEmpty || item.sourceUrl != null;
    return HistoryRecorder(
      item: ContentSnapshots.fanart(item),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppPageBar(
          title: const Text('二创详情'),
          actions: [
            ContentActionsButton(
              item: ContentSnapshots.fanart(item),
              ruleSubject: RuleSubjects.fanart(item),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            final info = <Widget>[
              _AuthorCard(item: item),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 18),
                if (item.images.isEmpty)
                  _Letter(item: item, text: text)
                else
                  SelectableText(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
                  ),
              ],
              if (item.images.isEmpty && text.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('这条动态没有可显示的正文或图片')),
                ),
              _Facts(item: item),
            ];
            if (constraints.maxWidth >= 1000 && item.images.isNotEmpty) {
              return _WideDetail(
                item: item,
                heroTag: heroTag,
                info: info,
                actions: actions,
                sideWidth: (constraints.maxWidth * .34).clamp(340, 440),
                onOpen: openViewer,
              );
            }
            final padding = MediaQuery.paddingOf(context);
            // The bar floats over the end of the page; the page ends clear
            // of it.
            final barSpace = hasActions
                ? AppSegments.heightFor(context) + 16 + 12
                : 0.0;
            final rest = item.images.length - 1;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: pageInsets(context, bottom: 24 + barSpace),
                      children: [
                        if (item.images.isNotEmpty) ...[
                          _DetailImage(
                            item: item,
                            index: 0,
                            // The first picture leads the page, so it may not
                            // push the author and the words far down.
                            cap: math.max(240, constraints.maxHeight * .55),
                            heroTag: heroTag,
                            onTap: () => openViewer(0),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ...info,
                        if (rest > 0) ...[
                          const SizedBox(height: 24),
                          _SetHeading(count: item.images.length),
                          const SizedBox(height: 10),
                          _ImageGrid(
                            item: item,
                            first: 1,
                            columns: rest <= 2 ? 2 : 3,
                            onOpen: openViewer,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (hasActions)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: padding.bottom + 12,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _FloatingBar(child: actions),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A wide window: the pictures large on one side, everything about them
/// on the other, with the set as thumbnails that bring a picture into view
/// and the two ways on at the foot of the column.
class _WideDetail extends StatefulWidget {
  const _WideDetail({
    required this.item,
    required this.heroTag,
    required this.info,
    required this.actions,
    required this.sideWidth,
    required this.onOpen,
  });
  final FanartItem item;
  final Object? heroTag;
  final List<Widget> info;
  final Widget actions;
  final double sideWidth;
  final ValueChanged<int> onOpen;

  @override
  State<_WideDetail> createState() => _WideDetailState();
}

class _WideDetailState extends State<_WideDetail> {
  late final _keys = [for (final _ in widget.item.images) GlobalKey()];

  void _reveal(int index) {
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: appMotion(context, AppTokens.emphasisMotion),
      curve: AppCurves.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);
    final images = widget.item.images;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerLowest,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  key: const ValueKey('fanart-detail-gallery'),
                  padding: pageInsets(context, horizontal: 24),
                  children: [
                    for (var index = 0; index < images.length; index++)
                      Padding(
                        key: _keys[index],
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _DetailImage(
                          item: widget.item,
                          index: index,
                          heroTag: index == 0 ? widget.heroTag : null,
                          onTap: () => widget.onOpen(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SizedBox(
            width: widget.sideWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    key: const ValueKey('fanart-detail-info'),
                    padding: pageInsets(context, horizontal: 20, bottom: 16),
                    children: [
                      ...widget.info,
                      if (images.length > 1) ...[
                        const SizedBox(height: 24),
                        _SetHeading(count: images.length),
                        const SizedBox(height: 10),
                        _ImageGrid(
                          item: widget.item,
                          first: 0,
                          columns: 3,
                          onOpen: _reveal,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, padding.bottom + 20),
                  child: widget.actions,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The two ways on: every picture at full size, and the post where it was
/// published.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.item,
    required this.onViewer,
    required this.onSource,
  });
  final FanartItem item;
  final VoidCallback? onViewer;
  final VoidCallback? onSource;

  @override
  Widget build(BuildContext context) {
    final height = AppSegments.heightFor(context);
    final count = item.images.length;
    return Row(
      spacing: 8,
      children: [
        if (onViewer != null)
          Expanded(
            child: SizedBox(
              height: height,
              child: AppButton.withIcon(
                filled: true,
                onPressed: onViewer,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  count > 1 ? '看原图 · $count 张' : '看原图',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        if (onSource != null)
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: Size(0, height),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.inputRadius),
                ),
              ),
              onPressed: onSource,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                item.identity.source == ContentSource.doubanTopic
                    ? '去豆瓣看原帖'
                    : '去 B 站看原动态',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

/// The action bar's own surface where it floats over the page.
class _FloatingBar extends StatelessWidget {
  const _FloatingBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const padding = 8.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        // Concentric with the buttons inside it.
        borderRadius: BorderRadius.circular(AppTokens.inputRadius + padding),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
        boxShadow: AppTokens.cardShadow(colors.brightness),
      ),
      child: Padding(padding: const EdgeInsets.all(padding), child: child),
    );
  }
}

/// A work that is only words, set as a letter: on the wash of the member
/// it is about, as its tile is, under an opening quote mark.
class _Letter extends StatelessWidget {
  const _Letter({required this.item, required this.text});
  final FanartItem item;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final members = {
      for (final tag in item.characterTags) ...AppTheme.membersIn(tag.wire),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: members.length == 1
            ? Color.alphaBlend(
                MemberTone.of(members.single, theme.brightness).wash,
                colors.surfaceContainerLow,
              )
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                '“',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colors.primary,
                  height: 1,
                ),
              ),
            ),
            SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 17,
                height: 1.85,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetHeading extends StatelessWidget {
  const _SetHeading({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('全部图片', style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        Text(
          '$count 张',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ],
    );
  }
}

/// The set from [first] on, as square thumbnails; a tap hands its index on.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.item,
    required this.first,
    required this.columns,
    required this.onOpen,
  });
  final FanartItem item;
  final int first;
  final int columns;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = first; index < item.images.length; index++)
              SizedBox.square(
                dimension: side,
                child: Semantics(
                  button: true,
                  label: '第 ${index + 1} 张图片',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: MediaImagePolicy.preview(
                            item.images[index],
                            logicalWidth: side,
                            logicalHeight: side,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        Material(
                          type: MaterialType.transparency,
                          child: InkWell(onTap: () => onOpen(index)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AuthorCard extends ConsumerWidget {
  const _AuthorCard({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mid =
        item.identity.source != ContentSource.doubanTopic &&
            validBilibiliMid(item.authorUid)
        ? item.authorUid
        : null;
    final member = [
      for (final tag in item.characterTags) ...AppTheme.membersIn(tag.wire),
    ].firstOrNull;
    final source = item.identity.source == ContentSource.doubanTopic
        ? '豆瓣'
        : 'B 站动态';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        children: [
          CreatorLink(
            mid: mid,
            child: MemberRing(
              member: member,
              size: 44,
              child: CircleAvatar(
                radius: member == null ? 22 : 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundImage: item.authorAvatarUrl == null
                    ? null
                    : MediaImagePolicy.preview(
                        item.authorAvatarUrl!,
                        logicalWidth: 44,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                      ),
                child: Text(
                  item.authorName.isEmpty
                      ? '?'
                      : item.authorName.characters.first,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CreatorLink(
              mid: mid,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.authorName.isEmpty ? '未知作者' : item.authorName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '发布于 $source',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (mid != null || item.authorSpaceUrl != null)
            AppButton(
              filled: true,
              onPressed: mid != null
                  ? () => openCreatorPage(context, mid)
                  : () => ref
                        .read(externalLinkServiceProvider)
                        .open(item.authorSpaceUrl!),
              child: const Text('作者主页'),
            ),
        ],
      ),
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
          detail: true,
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

/// Who appears and what kind of work it is, in the members' colours, and
/// how it has done where it was published.
class _Facts extends StatelessWidget {
  const _Facts({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget plain(String label, {IconData? icon}) => DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            if (icon != null)
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
      ),
    );
    final facts = <Widget>[
      for (final tag in item.characterTags)
        MemberTag(
          member: AppTheme.membersIn(tag.wire).firstOrNull ?? tag.wire,
          label: tag.wire,
        ),
      plain(item.category.wire),
      if (item.viewCount != null)
        plain('播放 ${item.viewCount}', icon: Icons.play_arrow_rounded),
      if (item.favoriteCount != null)
        plain('收藏 ${item.favoriteCount}', icon: Icons.star_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(spacing: 6, runSpacing: 6, children: facts),
    );
  }
}
