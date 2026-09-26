import 'package:asasfans_next/app/theme/app_theme.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/media_image_policy.dart';
import 'package:flutter/material.dart';

import '../visual_fixture.dart';

/// Prototype-only helpers for the U05 direction study. These screens are
/// built from the real theme, the real image policy and navigation bar and
/// the shared fixture, but they are prototypes: nothing here ships.

/// A root page with the real floating navigation bar, placed as the shell
/// places it on a phone.
class ProtoFrame extends StatelessWidget {
  const ProtoFrame({required this.tab, required this.child, super.key});
  final int tab;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bar = AppGlassNavigation.heightFor(mq.textScaler);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaQuery(
            data: mq.copyWith(padding: mq.padding.copyWith(bottom: bar + 28)),
            child: child,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: AppGlassNavigation(
              selected: tab,
              onSelect: (_) {},
              onTools: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// A network image through the real preview policy, clipped to [radius].
class ProtoArt extends StatelessWidget {
  const ProtoArt(
    this.uri, {
    this.ratio,
    this.radius = 12,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    super.key,
  });
  final Uri? uri;
  final double? ratio;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget image = LayoutBuilder(
      builder: (context, constraints) => uri == null
          ? ColoredBox(color: colors.surfaceContainerHighest)
          : Image(
              image: MediaImagePolicy.preview(
                uri!,
                logicalWidth: constraints.maxWidth,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
              fit: fit,
              alignment: alignment,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
    );
    if (ratio != null) image = AspectRatio(aspectRatio: ratio!, child: image);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: colors.surfaceContainerHighest, child: image),
    );
  }
}

/// A small dark label on an image corner.
class ProtoBadge extends StatelessWidget {
  const ProtoBadge(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 11),
      ),
    ),
  );
}

/// The badge a work shows: video hand-off, several images or a long image.
String? workBadge(FanartItem item) {
  if (item.contentType == FanartContentType.video) return '去 B 站看 ↗';
  if (item.images.length > 1) return '${item.images.length} 张';
  final first = item.images.firstOrNull;
  if (first != null) {
    final size = fixtureImages[first.pathSegments.last.replaceAll('.png', '')];
    if (size != null && size.$2 > size.$1 * 2.2) return '长图';
  }
  return null;
}

bool isTextWork(FanartItem item) =>
    item.contentType == FanartContentType.text ||
    (item.images.isEmpty && item.contentType != FanartContentType.video);

String workTitle(FanartItem item) {
  final text = item.text.trim();
  if (text.isNotEmpty) return text;
  return item.contentType == FanartContentType.video ? '视频作品' : '图片作品';
}

String members(FanartItem item) =>
    item.characterTags.map((tag) => tag.wire).join(' · ');

/// Shanghai wall time of a UTC instant, as HH:mm.
String hm(DateTime utc) {
  final local = utc.add(const Duration(hours: 8));
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// The fixture day's events and the next ones, as the Today schedule sees
/// them: today's first, then upcoming, cancelled ones kept but marked.
List<CalendarEvent> upcomingEvents() {
  final today = DateTime.utc(2026, 9, 26, -8);
  final list =
      fixtureEvents.where((event) => !event.start.isBefore(today)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return list;
}

String dayLabel(DateTime utc) {
  final local = utc.add(const Duration(hours: 8));
  final days = local.difference(DateTime.utc(2026, 9, 26)).inDays;
  return switch (days) {
    0 => '今天',
    1 => '明天',
    _ => '${local.month}月${local.day}日',
  };
}

/// Text status for an event; colour is never the only signal.
String? eventStatus(CalendarEvent event) => event.isCancelled
    ? '已取消'
    : event.sequence > 0
    ? '已改期'
    : null;

Color memberColor(CalendarEvent event) =>
    AppTheme.memberColors[event.members.firstOrNull] ?? AppTheme.dianaPink;

String relativeTime(DateTime? utc) {
  if (utc == null) return '';
  final hours = fixtureNow.difference(utc).inHours;
  if (hours < 24) return '$hours 小时前';
  return '${hours ~/ 24} 天前';
}

String duration(Duration? value) {
  if (value == null) return '';
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '${value.inMinutes}:$seconds';
}

String views(int? count) => count == null
    ? ''
    : count >= 10000
    ? '${(count / 10000).toStringAsFixed(1)}万播放'
    : '$count播放';
