import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../../content/presentation/content_images.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../application/novel_providers.dart';
import '../domain/novel_repository.dart';

void openNovel(BuildContext context, NovelSummary item) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => NovelReaderPage(item: item)));

String formatNovelCharCount(int count) {
  if (count < 10000) return '$count 字';
  final wan = count / 10000;
  final value = wan >= 10
      ? wan.toStringAsFixed(0)
      : wan.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  return '$value 万字';
}

/// Archive times are Shanghai wall-clock values; show the calendar date.
String formatNovelDate(DateTime value, {bool includeTime = false}) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}'
    '${includeTime ? ' ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}' : ''}';

Future<void> openNovelSource(
  BuildContext context,
  WidgetRef ref,
  Uri url,
) async {
  final opened = await ref.read(externalLinkServiceProvider).open(url);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开这个链接')));
  }
}

/// Reading page for one work. R18 works show only their metadata, warnings
/// and the links where they can be read.
class NovelReaderPage extends ConsumerWidget {
  const NovelReaderPage({required this.item, super.key});
  final NovelSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(novelDetailProvider(item.sourceTid));
    final source = item.sourceUrl;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        title: Text(item.title.isEmpty ? '小说' : item.title),
        actions: [
          if (source != null)
            AppGlassButton.icon(
              tooltip: '打开豆瓣原帖',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openNovelSource(context, ref, source),
            ),
        ],
      ),
      // The bar's inset is only visible from inside the body.
      body: Builder(
        builder: (context) => detail.when(
          skipLoadingOnRefresh: false,
          data: (value) => _NovelReader(detail: value),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            final failure = error is ApiFailure ? error : null;
            return FeedMessage(
              icon: Icons.cloud_off_outlined,
              text: failure?.message ?? '内容加载失败',
              failure: failure,
              onRetry: () =>
                  ref.invalidate(novelDetailProvider(item.sourceTid)),
            );
          },
        ),
      ),
    );
  }
}

class _NovelReader extends StatelessWidget {
  const _NovelReader({required this.detail});
  final NovelDetail detail;

  static const _measure = 720.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The list spans the window so it scrolls from anywhere; the text
      // column keeps a readable measure on wide screens.
      final side = math.max(20.0, (constraints.maxWidth - _measure) / 2);
      final header = _header(context);
      final tail = _tail(context);
      final blocks = detail.blocks;
      return SelectionArea(
        child: ListView.builder(
          key: PageStorageKey('novel-reader-${detail.summary.sourceTid}'),
          padding: pageInsets(context, horizontal: side, bottom: 48),
          itemCount: header.length + blocks.length + tail.length,
          itemBuilder: (context, index) {
            if (index < header.length) return header[index];
            index -= header.length;
            if (index < blocks.length) return _BlockView(block: blocks[index]);
            return tail[index - blocks.length];
          },
        ),
      );
    },
  );

  List<Widget> _header(BuildContext context) {
    final theme = Theme.of(context);
    final work = detail.summary;
    final meta = [
      work.authorName.isEmpty ? '匿名作者' : work.authorName,
      if (work.createdAt != null) formatNovelDate(work.createdAt!),
      if (work.charCount > 0) formatNovelCharCount(work.charCount),
      if (detail.externalCharCount > 0)
        '含附加文档 ${formatNovelCharCount(detail.externalCharCount)}',
    ].join(' · ');
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              work.title.isEmpty ? '无题' : work.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (work.isR18) ...[
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: NovelR18Badge(),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Text(
        meta,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (work.characters.isNotEmpty) ...[
        const SizedBox(height: 10),
        NovelCharacterTags(characters: work.characters),
      ],
      if (detail.warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Notice(
          icon: Icons.warning_amber_outlined,
          text: '内容提示：${detail.warnings.join('、')}',
        ),
      ],
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _tail(BuildContext context) {
    final theme = Theme.of(context);
    final links = [
      for (final link in detail.externalLinks) _LinkTile(link: link),
    ];
    if (!detail.contentVisible) {
      return [
        _Notice(
          icon: Icons.lock_outline,
          text:
              '这是 R18 作品，应用内不显示正文。'
              '${detail.primaryKind == NovelPrimaryKind.main ? '正文发布在豆瓣原帖，也可以查看作者附带的外部链接。' : '可以前往作者留下的外部文档或豆瓣原帖阅读。'}',
        ),
        const SizedBox(height: 16),
        if (links.isEmpty)
          Text('暂无可打开的链接', style: theme.textTheme.bodySmall)
        else
          ...links,
      ];
    }
    return [
      if (detail.blocks.isEmpty)
        const _Notice(
          icon: Icons.notes_outlined,
          text: '这篇作品没有可显示的正文，可以前往原帖查看。',
        ),
      if (links.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Text('原帖与附加文档', style: theme.textTheme.titleSmall),
        if (detail.externalLinks.any((l) => l.kind == NovelLinkKind.external))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '总字数包含已收录的附加文档，可打开以下链接继续阅读。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 4),
        ...links,
      ],
    ];
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});
  final NovelBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 17,
      height: 1.85,
      letterSpacing: .2,
    );
    return switch (block) {
      NovelTextBlock(
        style: NovelTextStyle.heading,
        :final text,
        :final level,
      ) =>
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Text(
            text,
            style:
                (level == 1
                        ? theme.textTheme.titleLarge
                        : level == 2
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w600, height: 1.5),
          ),
        ),
      NovelTextBlock(style: NovelTextStyle.quote, :final text) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant, width: 3),
          ),
        ),
        child: Text(
          text,
          style: body?.copyWith(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      NovelTextBlock(style: NovelTextStyle.preformatted, :final text) =>
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTokens.inputRadius),
          ),
          child: Text(
            text,
            style: body?.copyWith(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      // Chinese prose opens each paragraph with a two-character indent.
      NovelTextBlock(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text('　　$text', style: body),
      ),
      NovelImageBlock(:final url, :final alt) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          label: alt.isEmpty ? null : alt,
          child: ContentImageGallery(images: [url]),
        ),
      ),
      NovelDividerBlock() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(),
      ),
    };
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTokens.inputRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.link});
  final NovelExternalLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: AppGlassButton(
      onPressed: () => openNovelSource(context, ref, link.url),
      child: Row(
        children: [
          Icon(
            link.kind == NovelLinkKind.source
                ? Icons.forum_outlined
                : Icons.link,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.label),
                Text(
                  '${link.url.host}${link.url.path}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, size: 18),
        ],
      ),
    ),
  );
}

class NovelR18Badge extends StatelessWidget {
  const NovelR18Badge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppTokens.inputRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          'R18',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class NovelCharacterTags extends StatelessWidget {
  const NovelCharacterTags({required this.characters, super.key});
  final List<NovelCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final character in characters)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(AppTokens.inputRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                character.wire,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
