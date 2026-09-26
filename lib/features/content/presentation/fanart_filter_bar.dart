import '../../../shared/widgets/app_panel.dart';

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/query_summary.dart';

import '../application/fanart_filter_rules.dart';
import '../domain/fanart_repository.dart';

/// Members stay in the open as one chip strip, the one condition people
/// change most; every tap applies at once. Everything else lives in the
/// draft panel and shows in [FanartFilterBar] once it is set.
class FanartQuickFilters extends StatelessWidget {
  const FanartQuickFilters({
    required this.query,
    required this.onChanged,
    super.key,
  });
  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    // The inset lives inside the scroll view so chips scroll to the edge.
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      spacing: 6,
      children: [
        _QuickChip(
          label: '全部成员',
          selected: query.characters.isEmpty,
          onTap: () => onChanged(query.copyWith(characters: const {})),
        ),
        for (final character in FanartCharacter.values)
          _QuickChip(
            label: character.wire,
            selected: query.characters.contains(character),
            onTap: () => onChanged(
              query.copyWith(
                characters: query.characters.contains(character)
                    ? query.characters.difference({character})
                    : {...query.characters, character},
              ),
            ),
          ),
      ],
    ),
  );
}

/// A 30px pill; the transparent band around it widens the touch area without
/// making the strip taller to the eye (48 dp on touch platforms).
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = appMotion(context, AppTokens.controlMotion);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: (AppTokens.touchTarget(context) - 30) / 2,
          ),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 30),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    child: Text(label),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What else is applied, in words: the keyword and each panel condition
/// that differs from the default, each removable on its own, plus one way
/// to clear them all. Members are not repeated; their strip shows them.
/// Nothing is drawn while only defaults apply.
class FanartFilterBar extends StatelessWidget {
  const FanartFilterBar({
    required this.query,
    required this.onChanged,
    super.key,
  });
  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  static const _types = {
    FanartContentType.image: '图片',
    FanartContentType.video: '视频',
    FanartContentType.text: '文字',
    FanartContentType.other: '其他类型',
  };
  static const _sources = {
    FanartSource.bilibili: 'Bilibili',
    FanartSource.douban: '豆瓣',
  };
  static const _kinds = {FanartKind.material: '物料', FanartKind.all: '全部内容'};
  static const _sorts = {
    FanartSort.oldest: '最早',
    FanartSort.views: '播放最多',
    FanartSort.favorites: '收藏最多',
  };

  @override
  Widget build(BuildContext context) {
    void set(FanartQuery next) => onChanged(next);
    return QuerySummary(
      clearTooltip: '重置筛选',
      // Clears what this line shows; the members keep their own strip.
      onClear: () => onChanged(
        FanartFilterRules.reset(
          query,
        ).copyWith(keyword: '', characters: query.characters),
      ),
      applied: [
        if (query.keyword.isNotEmpty)
          (
            label: '“${query.keyword}”',
            remove: () => set(query.copyWith(keyword: '')),
          ),
        if (query.category != FanartCategory.all)
          (
            label: query.category.wire,
            remove: () => set(query.copyWith(category: FanartCategory.all)),
          ),
        if (_types[query.contentType] case final label?)
          (
            label: label,
            remove: () => set(
              FanartFilterRules.contentType(query, FanartContentType.all),
            ),
          ),
        if (_sources[query.source] case final label?)
          (
            label: label,
            remove: () =>
                set(FanartFilterRules.source(query, FanartSource.all)),
          ),
        if (_kinds[query.kind] case final label?)
          (
            label: label,
            remove: () => set(query.copyWith(kind: FanartKind.fanart)),
          ),
        if (_sorts[query.sort] case final label?)
          (
            label: label,
            remove: () => set(FanartFilterRules.sort(query, FanartSort.newest)),
          ),
      ],
    );
  }
}

class FanartFilterButton extends StatelessWidget {
  const FanartFilterButton({
    required this.query,
    required this.onChanged,
    super.key,
  });
  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = FanartFilterRules.count(query);
    return AppButton.icon(
      tooltip: '筛选',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.tune),
      ),
      onPressed: () async {
        final result = await showAppPanel<FanartQuery>(
          context: context,

          maxWidth: 600,
          builder: (_) => _FilterPanel(query: query),
        );
        if (result != null && context.mounted && result != query) {
          onChanged(result);
        }
      },
    );
  }
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({required this.query});
  final FanartQuery query;
  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late FanartQuery _draft = widget.query;
  void _change(FanartQuery query) => setState(() => _draft = query);

  @override
  Widget build(BuildContext context) => SizedBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanelHeader(
          title: '筛选',
          closeLabel: '关闭筛选',
          actions: [
            AppButton(
              onPressed: () => _change(FanartFilterRules.reset(_draft)),
              child: const Text('重置'),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Text('成员', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final character in FanartCharacter.values)
                    AppChoice(
                      label: Text(character.wire),
                      selected: _draft.characters.contains(character),
                      onSelected: (selected) => _change(
                        _draft.copyWith(
                          characters: {
                            ..._draft.characters.where(
                              (value) => selected || value != character,
                            ),
                            if (selected) character,
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _Options(
                title: '媒体类型',
                values: const {
                  FanartContentType.all: '全部类型',
                  FanartContentType.image: '图片',
                  FanartContentType.video: '视频',
                  FanartContentType.text: '文字',
                  FanartContentType.other: '其他',
                },
                value: _draft.contentType,
                onChanged: (value) =>
                    _change(FanartFilterRules.contentType(_draft, value)),
              ),
              _Options(
                title: '来源',
                values: const {
                  FanartSource.all: '全部来源',
                  FanartSource.bilibili: 'Bilibili',
                  FanartSource.douban: '豆瓣',
                },
                value: _draft.source,
                onChanged: (value) =>
                    _change(FanartFilterRules.source(_draft, value)),
              ),
              _Options(
                title: '内容',
                values: const {
                  FanartKind.fanart: '二创',
                  FanartKind.material: '物料',
                  FanartKind.all: '全部内容',
                },
                value: _draft.kind,
                onChanged: (value) => _change(_draft.copyWith(kind: value)),
              ),
              _Options(
                title: '分类',
                values: {
                  for (final value in FanartCategory.values)
                    value: value == FanartCategory.all ? '全部分类' : value.wire,
                },
                value: _draft.category,
                onChanged: (value) => _change(_draft.copyWith(category: value)),
              ),
              _Options(
                title: '排序',
                values: const {
                  FanartSort.newest: '最新',
                  FanartSort.oldest: '最早',
                  FanartSort.views: '播放最多',
                  FanartSort.favorites: '收藏最多',
                },
                value: _draft.sort,
                onChanged: (value) =>
                    _change(FanartFilterRules.sort(_draft, value)),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: AppButton(
              selected: true,
              onPressed: () => Navigator.pop(context, _draft),
              child: const Text('应用筛选'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Options<T> extends StatelessWidget {
  const _Options({
    required this.title,
    required this.values,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final Map<T, String> values;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final entry in values.entries)
              AppChoice(
                label: Text(entry.value),
                selected: value == entry.key,
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    ),
  );
}
