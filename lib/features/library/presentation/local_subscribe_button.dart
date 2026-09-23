import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';
import 'library_common.dart';

class LocalSubscribeButton extends ConsumerStatefulWidget {
  const LocalSubscribeButton({required this.creator, super.key});
  final LocalSubscription creator;
  @override
  ConsumerState<LocalSubscribeButton> createState() =>
      _LocalSubscribeButtonState();
}

class _LocalSubscribeButtonState extends ConsumerState<LocalSubscribeButton> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final subscribed = ref.watch(isSubscribedProvider(widget.creator.mid));
    if (subscribed.hasError) {
      return AppGlassButton(
        onPressed: () =>
            ref.invalidate(isSubscribedProvider(widget.creator.mid)),
        child: const Text('重试订阅状态'),
      );
    }
    final value = subscribed.valueOrNull;
    return AppGlassButton.withIcon(
      selected: true,
      icon: Icon(
        value == true ? Icons.person_remove_outlined : Icons.person_add_alt_1,
        size: 18,
      ),
      label: Text(
        _saving
            ? '保存中'
            : value == null
            ? '读取中'
            : value
            ? '已订阅'
            : '本地订阅',
      ),
      onPressed: _saving || value == null || subscribed.isLoading
          ? null
          : () async {
              final repository = ref.read(libraryRepositoryProvider);
              setState(() => _saving = true);
              final success = await libraryAction(
                context,
                () => value
                    ? repository.unsubscribe(widget.creator.mid)
                    : repository.subscribe(
                        LocalSubscription(
                          mid: widget.creator.mid,
                          name: widget.creator.name,
                          avatar: widget.creator.avatar,
                        ),
                      ),
              );
              if (!mounted) return;
              if (success) {
                ref.invalidate(isSubscribedProvider(widget.creator.mid));
              }
              setState(() => _saving = false);
            },
    );
  }
}
