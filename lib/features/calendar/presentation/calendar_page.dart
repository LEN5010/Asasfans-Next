import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_pending.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('日历')),
    body: const FeaturePending(icon: Icons.calendar_month_outlined),
  );
}
