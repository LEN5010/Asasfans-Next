import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../creator/presentation/creator_link.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/presentation/fanart_image_viewer.dart';
import '../domain/library_models.dart';
import 'content_actions.dart';
import 'history_recorder.dart';
import 'library_common.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/content_identity.dart';
import '../../handoff/domain/return_context.dart';

class SavedContentPage extends ConsumerWidget {
  const SavedContentPage({required this.item, super.key});
  final ContentSnapshot item;
  @override
  Widget build(BuildContext context, WidgetRef ref) => HistoryRecorder(
    item: item,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        title: const Text('内容详情'),
        actions: [
          ContentActionsButton(item: item),
          AppButton.icon(
            tooltip: '打开原站',
            onPressed: () => openContentSource(context, ref, item),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Builder(
        // Inside the body, so MediaQuery carries the page bar height.
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: pageInsets(context, horizontal: 20, top: 12),
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                CreatorLink(
                  mid: item.creator?.mid,
                  child: Text(
                    item.authorName.isEmpty ? '未知作者' : item.authorName,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 20),
                if (item.identity.source == ContentSource.bilibiliVideo &&
                    validBvid(item.identity.value))
                  Align(
                    alignment: Alignment.centerLeft,
                    // Videos are watched on Bilibili; the app has no detail page.
                    child: AppButton.withIcon(
                      onPressed: () => openContentSource(
                        context,
                        ref,
                        item,
                        returnTo: ReturnTarget.library,
                      ),
                      icon: const Icon(Icons.smart_display_outlined),
                      label: const Text('在 B 站观看'),
                    ),
                  ),
                if (item.body.isNotEmpty) SelectableText(item.body),
                const SizedBox(height: 16),
                for (var index = 0; index < item.images.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FanartImageViewer(
                                images: item.images,
                                initial: index,
                              ),
                            ),
                          ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTokens.cardRadius,
                        ),
                        child: Image.network(
                          item.images[index].toString(),
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 100,
                            child: Center(child: Text('图片加载失败')),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
