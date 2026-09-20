import 'package:flutter/material.dart';

class FeaturePending extends StatelessWidget {
  const FeaturePending({required this.icon, super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('即将开放'),
        ],
      ),
    ),
  );
}
