import '../../../shared/widgets/app_panel.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_tokens.dart';
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

class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({
    required this.event,
    this.day,
    this.showDate = false,
    this.compact = false,
    super.key,
  });
  final CalendarEvent event;
  final DateTime? day;
  final bool showDate;
  final bool compact;

  static final _tag = RegExp(r'【([^】]*)】');
  static final _colon = RegExp('[:：]');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cast = calendarEventCast(event);
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
    final live = EventClassifier.classify(event) == EventKind.live;
    final label =
        _tag.firstMatch(title)?.group(1)?.split('/').first.trim() ??
        (live ? '直播' : '日程');
    // White text throughout; the fill is dimmed so light colours carry it.
    final fill = event.isCancelled
        ? const Color(0xFF7D7881)
        : Color.lerp(calendarEventColor(event), Colors.black, .15)!;
    const foreground = Colors.white;
    final strike = event.isCancelled ? TextDecoration.lineThrough : null;
    final badges = [
      for (final badge in [
        label,
        if (event.isCancelled) '已取消',
        if (event.status == EventStatus.tentative) '待定',
      ])
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      if (live && !event.isCancelled)
        const Icon(Icons.sensors, size: 14, color: foreground),
    ];
    final heading = Text(
      headline,
      maxLines: compact ? 2 : 1,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50 * scale,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: fill,
            borderRadius: BorderRadius.circular(AppTokens.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCalendarEvent(context, event),
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground, decoration: strike),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: compact ? 44 : 50),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: compact ? 8 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tags trail the title and wrap below it only when
                            // the title leaves no room.
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [heading, ...badges],
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: compact ? 1 : null,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 12 : 13,
                                  height: 1.35,
                                  color: foreground.withValues(alpha: .88),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Who appears: one segment per member, or the fill's own
                    // colour when nobody is named.
                    SizedBox(
                      height: 3,
                      child: Row(
                        children: [
                          if (cast.isEmpty || event.isCancelled)
                            Expanded(child: ColoredBox(color: fill))
                          else
                            for (final member in cast)
                              Expanded(
                                child: ColoredBox(
                                  color: AppTheme.memberColors[member]!,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
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
