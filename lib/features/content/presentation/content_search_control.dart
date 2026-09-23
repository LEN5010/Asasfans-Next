import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../../../shared/widgets/glass/app_glass_surface.dart';

import '../../../shared/theme/app_icons.dart';

class ContentSearchControl extends StatelessWidget {
  const ContentSearchControl({
    required this.value,
    required this.hint,
    required this.onSubmitted,
    this.expanded = false,
    super.key,
  });
  final String value;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final bool expanded;

  @override
  Widget build(BuildContext context) => expanded
      ? SizedBox(
          width: 240,
          height: 44,
          child: AppGlassSurface(
            radius: 22,
            child: _SearchInput(
              key: ValueKey(value),
              value: value,
              hint: hint,
              onSubmitted: onSubmitted,
            ),
          ),
        )
      : AppGlassButton.icon(
          tooltip: '搜索',
          selected: value.isNotEmpty,
          icon: const Icon(AppIcons.search),
          onPressed: () async {
            final keyword = await showDialog<String>(
              context: context,
              builder: (_) => _SearchDialog(value: value, hint: hint),
            );
            if (keyword != null && context.mounted) onSubmitted(keyword);
          },
        );
}

class _SearchInput extends StatefulWidget {
  const _SearchInput({
    required this.value,
    required this.hint,
    required this.onSubmitted,
    super.key,
  });
  final String value;
  final String hint;
  final ValueChanged<String> onSubmitted;
  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    textInputAction: TextInputAction.search,
    maxLength: 200,
    // Fits the page bar's action capsule.
    decoration: InputDecoration(
      hintText: widget.hint,
      filled: false,
      counterText: '',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      prefixIconConstraints: const BoxConstraints.tightFor(width: 36),
      prefixIcon: const Icon(AppIcons.search, size: 20),
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: '清除搜索',
              icon: const Icon(AppIcons.close, size: 18),
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onSubmitted('');
              },
            ),
    ),
    onChanged: (_) => setState(() {}),
    onSubmitted: (value) => widget.onSubmitted(value.trim()),
  );
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.value, required this.hint});
  final String value;
  final String hint;
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('搜索'),
    content: SizedBox(
      width: 400,
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(hintText: widget.hint, counterText: ''),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
    ),
    actions: [
      AppGlassButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      if (widget.value.isNotEmpty)
        AppGlassButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('清除'),
        ),
      AppGlassButton(
        selected: true,
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('搜索'),
      ),
    ],
  );
}
