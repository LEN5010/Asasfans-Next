import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_time.dart';

final currentTimeProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// One application-scope day clock, rather than a polling timer per feature.
/// A sleeping desktop may skip midnight timers; resume recomputes today's key.
final localDateProvider = StateNotifierProvider<LocalDateController, DateTime>((
  ref,
) {
  final controller = LocalDateController(ref.watch(currentTimeProvider));
  final lifecycle = AppLifecycleListener(onResume: controller.resync);
  ref.onDispose(lifecycle.dispose);
  return controller;
});

class LocalDateController extends StateNotifier<DateTime> {
  LocalDateController(this._clock) : super(CalendarTime.dayOf(_clock())) {
    _offset = _clock().toLocal().timeZoneOffset;
    _arm();
  }
  final DateTime Function() _clock;
  late Duration _offset;
  Timer? _timer;

  void resync() {
    if (!mounted) return;
    final now = _clock().toLocal();
    final day = CalendarTime.dayOf(now);
    if (day != state || now.timeZoneOffset != _offset) state = day;
    _offset = now.timeZoneOffset;
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    final now = _clock();
    final local = now.toLocal();
    final next = DateTime(local.year, local.month, local.day + 1);
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
