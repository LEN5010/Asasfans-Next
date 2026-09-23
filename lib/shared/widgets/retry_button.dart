import 'dart:async';

import 'package:flutter/material.dart';

import 'glass/app_glass_controls.dart';

import '../../core/network/api_failure.dart';

/// Server cooldown controls both the visible action and the transport gate.
class RetryButton extends StatefulWidget {
  const RetryButton({
    required this.failure,
    required this.onRetry,
    this.label = '重试',
    this.filled = false,
    super.key,
  });
  final ApiFailure? failure;
  final VoidCallback? onRetry;
  final String label;
  final bool filled;

  @override
  State<RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<RetryButton> {
  Timer? _timer;
  bool get _waiting =>
      widget.failure?.retryAt?.isAfter(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(RetryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failure?.retryAt != widget.failure?.retryAt) _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (_waiting) {
      _timer = Timer(widget.failure!.retryAt!.difference(DateTime.now()), () {
        if (mounted) setState(_arm);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = _waiting ? null : widget.onRetry;
    final text = Text(_waiting ? '稍后重试' : widget.label);
    return widget.filled
        ? AppGlassButton(selected: true, onPressed: action, child: text)
        : AppGlassButton(onPressed: action, child: text);
  }
}
