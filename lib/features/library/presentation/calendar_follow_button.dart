import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../calendar/domain/calendar_event.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';
import 'library_common.dart';

class CalendarFollowButton extends ConsumerStatefulWidget {
  const CalendarFollowButton({required this.event, this.source, super.key});
  final CalendarEvent event;
  final Uri? source;
  @override
  ConsumerState<CalendarFollowButton> createState() =>
      _CalendarFollowButtonState();
}

class _CalendarFollowButtonState extends ConsumerState<CalendarFollowButton> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final key = CalendarFollowKey(
      source: widget.source ?? ref.watch(appEnvironmentProvider).calendarUrl,
      uid: widget.event.uid,
      recurrenceId: widget.event.recurrenceId,
    );
    final provider = isFollowingCalendarProvider(key);
    final entries = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        entries.when(
          loading: () => AppGlassButton.withIcon(
            onPressed: null,
            icon: Icon(Icons.star_border),
            label: Text('关注日程'),
          ),
          error: (error, _) => AppGlassButton.withIcon(
            onPressed: () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试关注状态'),
          ),
          data: (followed) {
            return AppGlassButton.withIcon(
              icon: Icon(followed ? Icons.star : Icons.star_border),
              label: Text(followed ? '已关注' : '关注日程'),
              onPressed: _busy || entries.isLoading
                  ? null
                  : () async {
                      final repository = ref.read(libraryRepositoryProvider);
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        if (followed) {
                          await repository.unfollowCalendar(key);
                        } else {
                          await repository.followCalendar(key, widget.event);
                        }
                      } catch (error) {
                        if (mounted) {
                          setState(() => _error = libraryError(error));
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            );
          },
        ),
      ],
    );
  }
}
