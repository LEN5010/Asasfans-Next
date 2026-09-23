import '../../../shared/widgets/app_panel.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/time/calendar_time.dart';
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

/// The member's support colour, or the group colour for shared and
/// unattributed events.
Color calendarEventColor(CalendarEvent event) {
  final members = EventClassifier.members(event);
  return AppTheme.memberColors[members.length == 1
      ? members.single
      : 'A-SOUL']!;
}

class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({
    required this.event,
    this.day,
    this.showDate = false,
    super.key,
  });
  final CalendarEvent event;
  final DateTime? day;
  final bool showDate;

  static final _tag = RegExp(r'【([^】]*)】');
  static final _colon = RegExp('[:：]');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = EventClassifier.members(event);
    final startDay = CalendarTime.dayOf(event.start, allDay: event.allDay);
    final date = showDate || (day != null && day != startDay);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // 【突击】嘉然突击：【突击】一起看… → 突击 / 嘉然突击 / 【突击】一起看…
    final title = event.title.trim();
    final split = title.indexOf(_colon);
    final head = (split < 0 ? title : title.substring(0, split))
        .replaceAll(_tag, '')
        .trim();
    final rest = split < 0 ? '' : title.substring(split + 1).trim();
    final headline = head.isNotEmpty
        ? head
        : rest.isNotEmpty
        ? rest
        : '未命名安排';
    final subtitle = head.isNotEmpty ? rest : '';
    final label =
        _tag.firstMatch(title)?.group(1)?.split('/').first.trim() ??
        (EventClassifier.classify(event) == EventKind.live ? '直播' : '日程');
    final color = event.isCancelled
        ? theme.colorScheme.surfaceContainerHighest
        : calendarEventColor(event);
    final foreground = event.isCancelled
        ? theme.colorScheme.outline
        : ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF2B1A20);
    final strike = event.isCancelled ? TextDecoration.lineThrough : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56 * scale.clamp(1.0, 1.7),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date)
                  Text(
                    '${startDay.month}-${startDay.day}',
                    style: theme.textTheme.labelSmall,
                  ),
                Text(
                  event.allDay ? '全天' : CalendarAgenda.time(event.start),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCalendarEvent(context, event),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground, decoration: strike),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final badge in [
                            label,
                            if (event.isCancelled) '已取消',
                            if (event.status == EventStatus.tentative) '待定',
                          ])
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: foreground.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        headline,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                      // A shared event wears the group colour; name its cast.
                      if (members.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          members.join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: foreground.withValues(alpha: .8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                  child: SelectableText(
                    event.title.isEmpty ? '未命名安排' : event.title,
                    style: theme.textTheme.titleLarge,
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
                if (members.isNotEmpty)
                  _DetailLine(
                    icon: Icons.people_outline,
                    label: '成员',
                    value: members.join(' · '),
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
                    FilledButton.icon(
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
