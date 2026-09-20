import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/library_providers.dart';
import '../domain/library_models.dart';

class HistoryRecorder extends ConsumerStatefulWidget {
  const HistoryRecorder({
    required this.item,
    required this.child,
    this.enabled = true,
    super.key,
  });
  final ContentSnapshot item;
  final Widget child;
  final bool enabled;
  @override
  ConsumerState<HistoryRecorder> createState() => _HistoryRecorderState();
}

class _HistoryRecorderState extends ConsumerState<HistoryRecorder> {
  int _generation = 0;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(HistoryRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.identity != widget.item.identity) {
      _generation++;
      _scheduled = false;
    }
    _schedule();
  }

  void _schedule() {
    if (!widget.enabled || _scheduled) return;
    _scheduled = true;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      if (!widget.enabled) {
        _scheduled = false;
        return;
      }
      _record();
    });
  }

  Future<void> _record() async {
    final item = widget.item;
    final generation = _generation;
    try {
      await ref
          .read(libraryRepositoryProvider)
          .recordHistory(item, HistoryAction.detail);
    } catch (_) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('历史记录保存失败'),
            action: SnackBarAction(label: '重试', onPressed: _record),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
