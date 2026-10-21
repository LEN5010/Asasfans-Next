import 'package:asasfans_next/app/theme/app_theme.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:asasfans_next/features/operations/data/collection_repository.dart';
import 'package:asasfans_next/features/operations/presentation/collection_page.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _collection() => {
  'id': 'cijian-gongming-2026',
  'title': '此间共鸣 · 2026 线下物料',
  'dates': '2026.10.24 — 10.25',
  'venue': '上海 · LIVERSE 音宇宙中心',
  'sourceUrl': 'https://www.bilibili.com/opus/1261071117627424786',
  'sourceAuthor': '一个魂儿周报',
  'groups': ['应援花墙', '团体无料'],
  'entries': [
    {
      'id': '1261580539396096000',
      'title': 'ASOUL 吧应援花墙与无料',
      'summary': '花墙与挂件',
      'author': 'ASOUL 吧',
      'authorUid': '3691001002592783',
      'sourceUrl': 'https://www.bilibili.com/opus/1261580539396096000',
      'groups': ['应援花墙', '团体无料'],
      'images': ['https://example.test/original.jpg'],
      'previews': [
        {
          'url': 'https://example.test/wall.jpg',
          'groups': ['应援花墙'],
        },
        {
          'url': 'https://example.test/gift.jpg',
          'groups': ['团体无料'],
        },
      ],
      'contentType': 'image',
    },
    {
      'id': 'BV1c3JZ6SEz6',
      'title': '星星挂件',
      'summary': '挂件视频展示',
      'author': '小魂',
      'authorUid': null,
      'sourceUrl': 'https://www.bilibili.com/video/BV1c3JZ6SEz6',
      'groups': ['团体无料'],
      'images': <String>[],
      'contentType': 'video',
    },
  ],
};

class _Api extends PublicApiClient {
  _Api(this.response) : super(Dio());
  final Map<String, dynamic> response;
  String? path;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    this.path = path;
    return response;
  }
}

void main() {
  test(
    'loads the public collection contract and keeps source identities',
    () async {
      final api = _Api(_collection());
      final collection = await CollectionRepository(
        api,
      ).get('cijian-gongming-2026');
      expect(api.path, 'app/collections/cijian-gongming-2026');
      expect(collection.entries.first.id, '1261580539396096000');
      expect(collection.entries.last.isVideo, isTrue);
      expect(collection.entries.last.previews, isEmpty);
    },
  );

  test(
    'group and word searches intersect across title, author and summary',
    () {
      final collection = CollectionRepository.decode(_collection());
      expect(collection.filteredEntries(query: 'asoul 挂件').length, 1);
      expect(collection.filteredEntries(group: '应援花墙', query: '小魂'), isEmpty);
      expect(collection.filteredEntries(group: '团体无料').length, 2);
      expect(collection.filteredEntries(query: '   ').length, 2);
    },
  );

  test('group preview leads the gallery while original images stay intact', () {
    final entry = CollectionRepository.decode(_collection()).entries.first;
    expect(entry.galleryImages('团体无料').map((url) => url.path), [
      '/gift.jpg',
      '/original.jpg',
      '/wall.jpg',
    ]);
    expect(entry.images.single.path, '/original.jpg');
  });

  test('invalid transport data remains a load failure', () {
    for (final json in [
      {..._collection(), 'entries': 'invalid'},
      {..._collection(), 'sourceUrl': 'javascript:alert(1)'},
    ]) {
      expect(
        () => CollectionRepository.decode(json),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });

  for (final width in [360.0, 1100.0]) {
    testWidgets('collection filters and search fit a $width page', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = _collection();
      for (final entry in json['entries'] as List) {
        entry['images'] = <String>[];
        entry['previews'] = <Object>[];
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionProvider(
              'test',
            ).overrideWith((ref) async => CollectionRepository.decode(json)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const FanartCollectionPage(collectionId: 'test'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('物料 2'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppChoice, '应援花墙'));
      await tester.pumpAndSettle();
      expect(find.text('物料 1'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '小魂');
      await tester.pumpAndSettle();
      expect(find.text('物料 0'), findsOneWidget);
      expect(find.text('没有找到相关物料'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
