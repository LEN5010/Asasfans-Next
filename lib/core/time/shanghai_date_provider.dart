import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_time.dart';

final currentTimeProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// One application-scope day clock, rather than a polling timer per feature.
/// A sleeping desktop may skip midnight timers; resume recomputes today's key.
final shanghaiDateProvider =
    StateNotifierProvider<ShanghaiDateController, DateTime>((ref) {
      final controller = ShanghaiDateController(ref.watch(currentTimeProvider));
      final lifecycle = AppLifecycleListener(onResume: controller.resync);
      ref.onDispose(lifecycle.dispose);
      return controller;
    });

class ShanghaiDateController extends StateNotifier<DateTime> {
  ShanghaiDateController(this._clock) : super(CalendarTime.dayOf(_clock())) {
    _arm();
  }
  final DateTime Function() _clock;
  Timer? _timer;

  void resync() {
    if (!mounted) return;
    final day = CalendarTime.dayOf(_clock());
    if (day != state) state = day;
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    final now = _clock();
    final local = CalendarTime.inShanghai(now);
    final next = CalendarTime.wallTimeToUtc(
      DateTime.utc(local.year, local.month, local.day + 1),
      CalendarTime.scheduleZone,
    );
    final remaining = next.difference(now.toUtc());
    _timer = Timer(
      remaining > Duration.zero ? remaining : const Duration(seconds: 1),
      resync,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
