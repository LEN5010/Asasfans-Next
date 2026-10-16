import '../../../shared/widgets/app_panel.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/query_summary.dart';

import '../application/fanart_filter_rules.dart';
import '../domain/fanart_repository.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/member_tone.dart';
import 'content_images.dart';

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
        MemberQuickChip(
          label: '全部成员',
          selected: query.characters.isEmpty,
          onTap: () => onChanged(query.copyWith(characters: const {})),
        ),
        for (final character in FanartCharacter.values)
          MemberQuickChip(
            label: character.wire,
            members: AppTheme.membersIn(character.wire),
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
      // Clears what this line shows; the members keep their own strip, and
      // the button says so.
      clearLabel: '清除条件',
      clearTooltip: '清除条件，成员不变',
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
    this.expanded = false,
    this.onPressed,
    super.key,
  });
  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;
  final bool expanded;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final count = FanartFilterRules.count(query);
    return AppButton.icon(
      tooltip: '筛选',
      selected: expanded || count > 0,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.tune),
      ),
      onPressed:
          onPressed ??
          () async {
            final result = await showAppPanel<FanartQuery>(
              context: context,
              builder: (context) => FanartFilterPanel(
                query: query,
                onApply: (query) => Navigator.pop(context, query),
                onClose: () => Navigator.pop(context),
              ),
            );
            if (result != null && context.mounted && result != query) {
              onChanged(result);
            }
          },
    );
  }
}

class FanartFilterPanel extends StatefulWidget {
  const FanartFilterPanel({
    required this.query,
    required this.onApply,
    required this.onClose,
    this.embedded = false,
    super.key,
  });
  final FanartQuery query;
  final ValueChanged<FanartQuery> onApply;
  final VoidCallback onClose;
  final bool embedded;
  @override
  State<FanartFilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FanartFilterPanel> {
  late FanartQuery _draft = widget.query;
  void _change(FanartQuery query) => setState(() => _draft = query);

  @override
  Widget build(BuildContext context) => AppFilterPanel(
    title: '筛选二创',
    embedded: widget.embedded,
    onReset: () => _change(FanartFilterRules.reset(_draft)),
    onApply: () => widget.onApply(_draft),
    onClose: widget.onClose,
    sections: [
      AppFilterSection(
        title: '成员',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChoice(
              selected: _draft.characters.isEmpty,
              onSelected: (_) => _change(_draft.copyWith(characters: const {})),
              label: const Text('全部成员'),
            ),
            for (final character in FanartCharacter.values)
              MemberChoiceButton(
                label: character.wire,
                members: AppTheme.membersIn(character.wire),
                selected: _draft.characters.contains(character),
                onPressed: () => _change(
                  _draft.copyWith(
                    characters: _draft.characters.contains(character)
                        ? _draft.characters.difference({character})
                        : {..._draft.characters, character},
                  ),
                ),
              ),
          ],
        ),
      ),
      AppFilterSection(
        title: '媒体类型',
        child: AppChoiceWrap<FanartContentType>(
          values: const [
            FanartContentType.all,
            FanartContentType.image,
            FanartContentType.video,
            FanartContentType.text,
            FanartContentType.other,
          ],
          labelOf: (value) => switch (value) {
            FanartContentType.all => '全部类型',
            FanartContentType.image => '图片',
            FanartContentType.video => '视频',
            FanartContentType.text => '文字',
            FanartContentType.other => '其他',
          },
          selected: _draft.contentType,
          onChanged: (value) =>
              _change(FanartFilterRules.contentType(_draft, value)),
        ),
      ),
      AppFilterSection(
        title: '来源',
        child: AppSegments<FanartSource>(
          values: FanartSource.values,
          labelOf: (value) => switch (value) {
            FanartSource.all => '全部来源',
            FanartSource.bilibili => 'Bilibili',
            FanartSource.douban => '豆瓣',
          },
          selected: _draft.source,
          onChanged: (value) =>
              _change(FanartFilterRules.source(_draft, value)),
        ),
      ),
      AppFilterSection(
        title: '内容',
        child: AppSegments<FanartKind>(
          values: const [
            FanartKind.fanart,
            FanartKind.material,
            FanartKind.all,
          ],
          labelOf: (value) => switch (value) {
            FanartKind.fanart => '二创',
            FanartKind.material => '物料',
            FanartKind.all => '全部内容',
          },
          selected: _draft.kind,
          onChanged: (value) => _change(_draft.copyWith(kind: value)),
        ),
      ),
      AppFilterSection(
        title: '分类',
        child: AppChoiceWrap<FanartCategory>(
          values: [
            FanartCategory.all,
            for (final value in FanartCategory.values)
              if (value != FanartCategory.all) value,
          ],
          labelOf: (value) => value == FanartCategory.all ? '全部分类' : value.wire,
          selected: _draft.category,
          onChanged: (value) => _change(_draft.copyWith(category: value)),
        ),
      ),
      AppFilterSection(
        title: '排序',
        child: AppSegments<FanartSort>(
          values: FanartSort.values,
          labelOf: (value) => switch (value) {
            FanartSort.newest => '最新',
            FanartSort.oldest => '最早',
            FanartSort.views => '播放最多',
            FanartSort.favorites => '收藏最多',
          },
          selected: _draft.sort,
          onChanged: (value) => _change(FanartFilterRules.sort(_draft, value)),
        ),
      ),
    ],
  );
}
