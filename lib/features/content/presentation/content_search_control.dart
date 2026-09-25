import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';

import '../../../shared/theme/app_icons.dart';

class ContentSearchControl extends StatelessWidget {
  const ContentSearchControl({
    required this.value,
    required this.hint,
    required this.onSubmitted,
    this.expanded = false,
    this.filter,
    super.key,
  });
  final String value;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final bool expanded;

  /// The feed's filter action, beside the field (not inside it: a button in
  /// the field's suffix got inverted semantics once the field was partly
  /// scrolled away, and the field is too short for a 48 dp hit area).
  final Widget? filter;

  /// A feed's search row stays this wide on large windows, left-aligned.
  static const rowWidth = 560.0;

  @override
  Widget build(BuildContext context) => expanded
      ? SizedBox(
          width: 240,
          child: Row(
            spacing: 4,
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSegments.heightFor(context),
                  child: _SearchInput(
                    key: ValueKey(value),
                    value: value,
                    hint: hint,
                    onSubmitted: onSubmitted,
                  ),
                ),
              ),
              ?filter,
            ],
          ),
        )
      : AppButton.icon(
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
    textAlignVertical: TextAlignVertical.center,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.25),
    maxLength: 200,
    // Ordinary search surface; the text controller survives material changes.
    decoration: InputDecoration(
      hintText: widget.hint,
      filled: true,
      counterText: '',
      // Not dense: the 48 minimum is clipped to the control height, so the
      // fill spans it on every density and lines up with the square buttons.
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      prefixIconConstraints: const BoxConstraints.tightFor(width: 36),
      prefixIcon: const Icon(AppIcons.search, size: 20),
      suffixIconConstraints: const BoxConstraints(),
      suffixIcon: _controller.text.isEmpty
          ? null
          // Inside the field, which is itself the touch surface. One merged
          // node: a separate button node under the suffix's own node got an
          // inverted rect once the field was partly scrolled away.
          : MergeSemantics(
              child: Theme(
                data: Theme.of(context).copyWith(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: AppButton.icon(
                  tooltip: '清除搜索',
                  icon: const Icon(AppIcons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onSubmitted('');
                  },
                ),
              ),
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
      AppButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      if (widget.value.isNotEmpty)
        AppButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('清除'),
        ),
      AppButton(
        selected: true,
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('搜索'),
      ),
    ],
  );
}
