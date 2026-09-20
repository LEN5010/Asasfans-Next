import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLinkService implements ExternalLinkService {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

FanartItem _item({
  String id = 'a',
  String text = '正文内容',
  List<String> images = const [],
  Uri? sourceUrl,
  Uri? spaceUrl,
  FanartCategory category = FanartCategory.normal,
  List<FanartCharacter> tags = const [],
  int? views,
}) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: text,
  authorName: '作者$id',
  authorUid: '1',
  images: images.map(Uri.parse).toList(),
  kind: FanartKind.fanart,
  contentType: FanartContentType.image,
  category: category,
  characterTags: tags,
  sourceUrl: sourceUrl,
  authorSpaceUrl: spaceUrl,
  viewCount: views,
);

class _StubRepository implements FanartRepository {
  static const pages = 2;
  static const pageSize = 8;
  int requests = 0;

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    requests++;
    final index = cursor == null ? 0 : int.parse(cursor);
    return FanartPage(
      items: [
        for (var i = 0; i < pageSize; i++)
          _item(id: 'p${index}i$i', text: '作品 p${index}i$i'),
      ],
      snapshotId: 'snap-1',
      nextCursor: index + 1 < pages ? '${index + 1}' : null,
    );
  }
}

Widget _detail(FanartItem item, {ExternalLinkService? links}) => ProviderScope(
  overrides: [
    if (links != null) externalLinkServiceProvider.overrideWithValue(links),
  ],
  child: MaterialApp(home: FanartDetailPage(item: item)),
);

void main() {
  testWidgets('detail shows the full post text without truncating it', (
    tester,
  ) async {
    final long = '这是一段很长的二创正文。' * 20;
    await tester.pumpWidget(_detail(_item(text: long)));
    await tester.pumpAndSettle();

    final widget = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(widget.data, long);
  });

  testWidgets('detail lists every image rather than only a cover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _detail(
        _item(
          images: const [
            'https://img.test/1.png',
            'https://img.test/2.png',
            'https://img.test/3.png',
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('tapping an image opens the zoomable viewer', (tester) async {
    await tester.pumpWidget(
      _detail(_item(images: const ['https://img.test/1.png'])),
    );
    await tester.pump();

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.byType(FanartImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
  });

  testWidgets('the source link opens externally and is not fetched in-app', (
    tester,
  ) async {
    final links = _RecordingLinkService();
    final source = Uri.parse('https://www.bilibili.com/opus/1');
    await tester.pumpWidget(_detail(_item(sourceUrl: source), links: links));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开原动态'));
    await tester.pumpAndSettle();

    expect(links.opened, [source]);
  });

  testWidgets('category and character tags are shown as real metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _detail(
        _item(
          category: FanartCategory.amv,
          tags: const [FanartCharacter.diana],
          views: 1200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('剪辑·AMV'), findsOneWidget);
    expect(find.text('嘉然'), findsOneWidget);
    expect(find.text('播放 1200'), findsOneWidget);
  });

  testWidgets('a post with neither text nor images says so explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(_detail(_item(text: '   ')));
    await tester.pumpAndSettle();

    expect(find.text('这条动态没有可显示的正文或图片'), findsOneWidget);
  });

  testWidgets(
    'returning from a detail keeps the scroll position and loaded pages',
    (tester) async {
      final repository = _StubRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fanartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: ContentPage()),
        ),
      );
      await tester.pumpAndSettle();

      // The filter bar is also scrollable, so target the grid explicitly.
      final grid = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      // Scroll into the second page so there is a position worth preserving.
      await tester.scrollUntilVisible(
        find.text('作品 p1i0'),
        400,
        scrollable: grid,
      );
      await tester.pumpAndSettle();
      final requestsBefore = repository.requests;
      final offset = tester.widget<Scrollable>(grid).controller!.offset;

      await tester.tap(find.text('作品 p1i0'));
      await tester.pumpAndSettle();
      expect(find.byType(FanartDetailPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.widget<Scrollable>(grid).controller!.offset, offset);
      // Opening a detail must not re-fetch the list.
      expect(repository.requests, requestsBefore);
    },
  );
}
