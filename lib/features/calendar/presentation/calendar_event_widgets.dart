import 'dart:math' as math;

import '../../../shared/widgets/app_panel.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/member_tone.dart';
import '../../../core/time/calendar_time.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../domain/calendar_agenda.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';
import '../../library/presentation/calendar_follow_button.dart';

Future<void> showCalendarEvent(
  BuildContext context,
  CalendarEvent event, {
  Uri? source,
}) => showAppPanel<void>(
  context: context,

  maxWidth: 680,
  builder: (_) => CalendarEventDetail(event: event, source: source),
);

const _cast = ['嘉然', '乃琳', '贝拉', '心宜', '思诺'];

/// Who appears, for the colour strip: the group mark stands for everyone.
List<String> calendarEventCast(CalendarEvent event) {
  final members = EventClassifier.members(event);
  return members.contains('A-SOUL') ? _cast : members;
}

/// A solo event wears its member's support colour; a shared or group event
/// wears the group colour, dimmed so it does not glare.
Color calendarEventColor(CalendarEvent event) {
  final members = EventClassifier.members(event);
  return members.length == 1 && members.single != 'A-SOUL'
      ? AppTheme.memberColors[members.single]!
      : Color.lerp(AppTheme.memberColors['A-SOUL'], Colors.black, .18)!;
}

final _tag = RegExp(r'【([^】]*)】');
final _colon = RegExp('[:：]');

/// An event title split for display.
/// 【突击】嘉然突击：【突击】一起看… → 突击 / 嘉然突击 / 【突击】一起看…
({String headline, String subtitle, String label, bool live})
calendarEventParts(CalendarEvent event) {
  final title = event.title.trim();
  final split = title.indexOf(_colon);
  final head = (split < 0 ? title : title.substring(0, split))
      .replaceAll(_tag, '')
      .trim();
  final rest = split < 0 ? '' : title.substring(split + 1).trim();
  final live = EventClassifier.classify(event) == EventKind.live;
  return (
    headline: head.isNotEmpty
        ? head
        : rest.isNotEmpty
        ? rest
        : '未命名安排',
    subtitle: head.isNotEmpty ? rest : '',
    label:
        _tag.firstMatch(title)?.group(1)?.split('/').first.trim() ??
        (live ? '直播' : '日程'),
    live: live,
  );
}

/// Where an event stands against [now], by its schedule alone: still to
/// come (and how soon), under way, or over. A schedule, not a report of a
/// live room; cancelled and all-day events have no such state.
String? calendarEventTiming(CalendarEvent event, DateTime now) {
  if (event.isCancelled || event.allDay) return null;
  if (!now.isBefore(event.end) && event.end.isAfter(event.start)) {
    return '已结束';
  }
  if (!now.isBefore(event.start)) {
    return event.end.isAfter(event.start) ? '进行中' : '已结束';
  }
  final left = event.start.difference(now);
  if (left.inMinutes < 1) return '即将开始';
  if (left.inMinutes < 60) return '还有 ${left.inMinutes} 分钟';
  if (left.inHours < 24) {
    final minutes = left.inMinutes % 60;
    return minutes == 0
        ? '还有 ${left.inHours} 小时'
        : '还有 ${left.inHours} 小时 $minutes 分';
  }
  return '${left.inDays} 天后';
}

/// One agenda line: time, who (a bar in their colours), what, and its kind
/// in words. [highlight] lifts the line onto a wash of its member's colour
/// with how soon it starts, for the next thing on a day; given [now], a
/// line that is over steps back.
class CalendarAgendaRow extends StatelessWidget {
  const CalendarAgendaRow({
    required this.event,
    this.showDay = false,
    this.today,
    this.now,
    this.highlight = false,
    super.key,
  });
  final CalendarEvent event;

  /// Show which day, for an event that is not on the list's own day.
  final bool showDay;

  /// The Shanghai day the list is anchored to, for 今天/明天 labels.
  final DateTime? today;

  /// The present moment, when the line should say where it stands.
  final DateTime? now;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (:headline, :subtitle, :label, :live) = calendarEventParts(event);
    final cast = calendarEventCast(event);
    final startDay = CalendarTime.dayOf(event.start, allDay: event.allDay);
    final gap = today == null ? null : startDay.difference(today!).inDays;
    final day = switch (gap) {
      0 => '今天',
      1 => '明天',
      _ => '${startDay.month}月${startDay.day}日',
    };
    final state = event.isCancelled
        ? '已取消'
        : event.status == EventStatus.tentative
        ? '待定'
        : label;
    final muted = event.isCancelled;
    final timing = now == null ? null : calendarEventTiming(event, now!);
    final over = timing == '已结束';
    // The kind is said in the member's own colour; the group's is warm.
    final tone = MemberTone.of(
      cast.length == 1 ? cast.single : 'A-SOUL',
      theme.brightness,
    );
    final stateStyle = theme.textTheme.labelMedium?.copyWith(
      color: muted ? colors.error : tone.text,
    );
    final lifted = highlight && !muted && !over;
    final timeStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontFeatures: AppTheme.tabular,
      color: muted ? colors.onSurfaceVariant : null,
    );
    // The column is as wide as its widest words at this text size, so a
    // time never breaks across lines when the type is large.
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final timeWidth = math.max(
      54.0,
      math.max(
            measure('00:00', timeStyle),
            showDay ? measure(day, theme.textTheme.bodySmall) : 0.0,
          ) +
          8,
    );
    final time = Text(
      event.allDay ? '全天' : CalendarAgenda.time(event.start),
      maxLines: 1,
      style: timeStyle,
    );
    final dayLabel = Text(day, maxLines: 1, style: theme.textTheme.bodySmall);
    // Who appears: one segment per member.
    final bar = MemberBar(
      members: muted ? const [] : cast,
      fallback: muted ? colors.outlineVariant : calendarEventColor(event),
      length: 38,
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lifted && timing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              timing == '进行中' ? '进行中' : '下一场 · $timing',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ),
        Text(
          headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.35,
            fontWeight: FontWeight.w600,
            decoration: muted ? TextDecoration.lineThrough : null,
            color: muted ? colors.onSurfaceVariant : null,
          ),
        ),
        // What kind of event, beside what it is about: the state never
        // sits apart at the far end of the line.
        Text.rich(
          TextSpan(
            children: [
              if (state.isNotEmpty) TextSpan(text: state, style: stateStyle),
              if (subtitle.isNotEmpty)
                TextSpan(
                  text: state.isEmpty ? subtitle : ' · $subtitle',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    // Beside the words while the time column leaves them room; at very
    // large text the time goes above them instead of squeezing them out.
    final line = LayoutBuilder(
      builder: (context, constraints) {
        if (timeWidth <= constraints.maxWidth * .4) {
          return Row(
            children: [
              SizedBox(
                width: timeWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [time, if (showDay) dayLabel],
                ),
              ),
              bar,
              const SizedBox(width: 12),
              Expanded(child: words),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [time, if (showDay) dayLabel],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                bar,
                const SizedBox(width: 12),
                Expanded(child: words),
              ],
            ),
          ],
        );
      },
    );
    return Semantics(
      button: true,
      child: Opacity(
        opacity: over ? .55 : 1,
        child: Material(
          color: lifted ? tone.wash : Colors.transparent,
          // Inside a card's padding, so the corners follow the card's.
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showCalendarEvent(context, event),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: lifted
                    ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
                    : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: line,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day in a strip or a month: its number in a circle (filled when
/// selected, ringed when today) and a dot per event in its member's colour.
/// With [weekday], the day's name sits above, for a strip with no header.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    required this.day,
    required this.events,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    this.weekday,
    super.key,
  });
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;
  final String? weekday;

  static double _circle(TextScaler scaler) =>
      (scaler.scale(14) * 1.35 + 14).clamp(32, double.infinity);

  /// The cell's height at the current text size, with or without its name.
  static double heightFor(BuildContext context, {bool weekday = false}) {
    final scaler = MediaQuery.textScalerOf(context);
    return _circle(scaler) +
        15 +
        (weekday ? (scaler.scale(11) * 1.3).ceilToDouble() + 4 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = events.length;
    final duration = appMotion(context, AppTokens.controlMotion);
    final number = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.35,
      fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
      fontFeatures: AppTheme.tabular,
      color: isSelected
          ? AppTheme.ink
          : isToday
          ? colors.primary
          : colors.onSurface,
    );
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${day.year} 年 ${CalendarAgenda.date(day)}，$count 项安排',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (weekday != null) ...[
              Text(
                weekday!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isToday ? colors.primary : null,
                ),
              ),
              const SizedBox(height: 4),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final circle = _circle(
                  MediaQuery.textScalerOf(context),
                ).clamp(0.0, constraints.maxWidth - 2).toDouble();
                return AnimatedContainer(
                  duration: duration,
                  curve: AppCurves.standard,
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.dianaPink : Colors.transparent,
                    border: Border.all(
                      color: isToday && !isSelected
                          ? colors.primary.withValues(alpha: .7)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${day.day}', maxLines: 1, style: number),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // One dot per event in its member's colour.
                  for (final event in events.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event.isCancelled
                            ? colors.outlineVariant
                            : calendarEventColor(event),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The week holding [selected], Monday first, as seven day cells. With
/// [weekdays] each cell carries its day's name.
class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    required this.selected,
    required this.today,
    required this.events,
    required this.onSelect,
    this.weekdays = true,
    super.key,
  });
  final DateTime selected;
  final DateTime today;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelect;
  final bool weekdays;

  static const names = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final monday = CalendarAgenda.weekStart(selected);
    return SizedBox(
      height: CalendarDayCell.heightFor(context, weekday: weekdays),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: CalendarDayCell(
                day: monday.add(Duration(days: i)),
                weekday: weekdays ? names[i] : null,
                events: CalendarAgenda.onDay(
                  events,
                  monday.add(Duration(days: i)),
                ),
                isSelected: selected == monday.add(Duration(days: i)),
                isToday: today == monday.add(Duration(days: i)),
                onTap: () => onSelect(monday.add(Duration(days: i))),
              ),
            ),
        ],
      ),
    );
  }
}

class CalendarEventDetail extends ConsumerStatefulWidget {
  const CalendarEventDetail({required this.event, this.source, super.key});
  final CalendarEvent event;
  final Uri? source;
  @override
  ConsumerState<CalendarEventDetail> createState() =>
      _CalendarEventDetailState();
}

class _CalendarEventDetailState extends ConsumerState<CalendarEventDetail> {
  bool _opening = false;
  bool _openFailed = false;

  Future<void> _openSource() async {
    final url = widget.event.sourceUrl;
    if (_opening || url == null) return;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final opened = await ref.read(externalLinkServiceProvider).open(url);
    if (mounted) {
      setState(() {
        _opening = false;
        _openFailed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final theme = Theme.of(context);
    final members = EventClassifier.members(event);
    final timing = calendarEventTiming(event, ref.watch(currentTimeProvider)());
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPanelHeader(title: '日程详情', closeLabel: '关闭日程'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 10),
                  child: SelectableText(
                    event.title.isEmpty ? '未命名安排' : event.title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // Who, in their colours, and where it stands by the clock.
                if (members.isNotEmpty || timing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final member in members) MemberTag(member: member),
                        if (timing != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              timing,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                CalendarFollowButton(event: event, source: widget.source),
                _DetailLine(
                  icon: Icons.schedule,
                  label: event.allDay ? '日期' : '时间（上海）',
                  value: CalendarAgenda.range(event),
                ),
                _DetailLine(
                  icon: Icons.event_available_outlined,
                  label: '状态',
                  value: switch (event.status) {
                    EventStatus.confirmed => '已确认',
                    EventStatus.tentative => '待定',
                    EventStatus.cancelled => '已取消',
                  },
                ),
                if (event.location.isNotEmpty)
                  _DetailLine(
                    icon: Icons.place_outlined,
                    label: '地点',
                    value: event.location,
                  ),
                if (event.categories.isNotEmpty)
                  _DetailLine(
                    icon: Icons.label_outline,
                    label: '分类',
                    value: event.categories.join(' · '),
                  ),
                if (event.description.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text('简介', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  SelectableText(
                    event.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (event.sourceUrl != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_openFailed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            '无法打开链接',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    AppButton.withIcon(
                      selected: true,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('打开原站'),
                      onPressed: _opening ? null : _openSource,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              SelectableText(value),
            ],
          ),
        ),
      ],
    ),
  );
}

class CalendarStaleBanner extends StatelessWidget {
  const CalendarStaleBanner({required this.fetchedAt, super.key});
  final DateTime fetchedAt;
  @override
  Widget build(BuildContext context) {
    final local = CalendarTime.inShanghai(fetchedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '缓存内容 · 上次同步 ${local.month}-${local.day} ${CalendarAgenda.time(fetchedAt)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class CalendarCacheFailureBanner extends StatelessWidget {
  const CalendarCacheFailureBanner({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      '离线缓存未保存',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

class CalendarFollowSyncBanner extends StatelessWidget {
  const CalendarFollowSyncBanner({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      '关注日程同步失败',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}
