import 'package:asasfans_next/shared/widgets/resume_when_visible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Page extends StatefulWidget {
  const _Page(this.log);
  final List<String> log;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with ResumeWhenVisible {
  @override
  void onVisibleResume() => widget.log.add('refresh');
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  Future<void> cycle(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  testWidgets('a visible page refreshes on resume; a hidden one waits', (
    tester,
  ) async {
    final visible = <String>[];
    final hidden = <String>[];
    final shown = ValueNotifier(false);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            _Page(visible),
            ValueListenableBuilder(
              valueListenable: shown,
              builder: (_, on, child) => TickerMode(enabled: on, child: child!),
              child: _Page(hidden),
            ),
          ],
        ),
      ),
    );
    await cycle(tester);
    expect(visible, ['refresh']);
    expect(hidden, isEmpty, reason: 'an offstage branch does no work');
    // Two resumes while hidden are one refresh when it is finally shown.
    await cycle(tester);
    shown.value = true;
    await tester.pump();
    expect(hidden, ['refresh']);
    // Shown again without a resume in between: nothing to catch up on.
    shown.value = false;
    await tester.pump();
    shown.value = true;
    await tester.pump();
    expect(hidden, ['refresh']);
  });
}
