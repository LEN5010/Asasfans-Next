import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/data/dynamic_fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Uri.parse('https://example.test/dynamics/api/');

  test('preserves opaque cursors and source identities', () {
    final page = DynamicFanartRepository.decodePage({
      'items': [
        {
          'sourceDynamicId': '697635970322792467',
          'text': '作品',
          'images': ['https://img.test/a.png'],
          'newServerField': true,
        },
        {
          'sourceDynamicId': 'douban:123',
          'images': ['/dynamics/api/fanart/media/abc', 'javascript:alert(1)'],
        },
      ],
      'nextCursor': 'opaque_cursor_A-1',
      'snapshot': {'id': 'snapshot-1'},
    }, baseUrl: base);
    expect(page.nextCursor, 'opaque_cursor_A-1');
    expect(page.items.first.identity.value, '697635970322792467');
    expect(page.items.last.identity.source, ContentSource.doubanTopic);
    expect(
      page.items.last.images.single.toString(),
      'https://example.test/dynamics/api/fanart/media/abc',
    );
  });

  test('does not turn malformed data into a successful empty page', () {
    expect(
      () => DynamicFanartRepository.decodePage({
        'items': 'broken',
        'snapshot': {'id': 's'},
      }, baseUrl: base),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('null cursor explicitly represents the end of a list', () {
    final page = DynamicFanartRepository.decodePage({
      'items': <Object?>[],
      'nextCursor': null,
      'snapshot': {'id': 's'},
    }, baseUrl: base);
    expect(page.nextCursor, isNull);
    expect(page.items, isEmpty);
  });

  test('decodes the facets the deployed service actually returns', () {
    final page = DynamicFanartRepository.decodePage({
      'items': [
        {
          'sourceDynamicId': '1',
          'kind': 'material',
          'contentType': 'video',
          'category': '剪辑·AMV',
          'characterTags': ['嘉然', '未知角色'],
          'mediaUrl': 'https://cdn.test/v.mp4',
          'authorUid': '25996388',
          'authorAvatarUrl': 'https://i0.hdslb.com/a.jpg',
          'authorSpaceUrl': 'https://space.bilibili.com/25996388',
          'viewCount': 1200,
          'favoriteCount': 34,
        },
      ],
      'total': 22940,
      'nextCursor': 'n1',
      'prevCursor': 'p1',
      'snapshot': {'id': 's', 'moderationVersion': 7},
    }, baseUrl: base);

    final item = page.items.single;
    expect(item.kind, FanartKind.material);
    expect(item.contentType, FanartContentType.video);
    expect(item.category, FanartCategory.amv);
    expect(item.characterTags, [FanartCharacter.diana]);
    expect(item.mediaUrl.toString(), 'https://cdn.test/v.mp4');
    expect(item.viewCount, 1200);
    expect(page.prevCursor, 'p1');
    expect(page.total, 22940);
  });

  test('an unknown category degrades instead of dropping the item', () {
    final page = DynamicFanartRepository.decodePage({
      'items': [
        {'sourceDynamicId': '1', 'category': '服务端新增分类'},
      ],
      'snapshot': {'id': 's'},
    }, baseUrl: base);
    expect(page.items, hasLength(1));
    expect(page.items.single.category, FanartCategory.normal);
  });

  test('sends every filter the server validates', () {
    final query = DynamicFanartRepository.buildQuery(
      const FanartQuery(
        keyword: '  嘉然  ',
        characters: {FanartCharacter.diana, FanartCharacter.bella},
        kind: FanartKind.all,
        contentType: FanartContentType.video,
        category: FanartCategory.amv,
        sort: FanartSort.views,
        source: FanartSource.bilibili,
        limit: 48,
      ),
      cursor: 'c1',
    );
    expect(query['q'], '嘉然');
    expect(query['character'], '嘉然,贝拉');
    expect(query['category'], '剪辑·AMV');
    expect(query['sort'], 'views');
    expect(query['source'], 'bilibili');
    expect(query['limit'], 48);
    expect(query['cursor'], 'c1');
  });

  test('omits an empty keyword and the default source', () {
    final query = DynamicFanartRepository.buildQuery(const FanartQuery());
    expect(query.containsKey('q'), isFalse);
    expect(query.containsKey('source'), isFalse);
    expect(query.containsKey('cursor'), isFalse);
    expect(query.containsKey('character'), isFalse);
  });

  test('random mode never carries a cursor', () {
    // Random mode and cursors are mutually exclusive server-side.
    final query = DynamicFanartRepository.buildQuery(
      const FanartQuery(limit: 1),
    );
    expect(query.containsKey('cursor'), isFalse);
    expect(query['limit'], 1);
  });

  test('metric sort is rejected locally unless restricted to videos', () {
    const videoSort = FanartQuery(
      sort: FanartSort.views,
      contentType: FanartContentType.video,
    );
    expect(videoSort.isServerAcceptable, isTrue);
    expect(
      const FanartQuery(sort: FanartSort.views).isServerAcceptable,
      isFalse,
    );
    expect(
      videoSort.copyWith(source: FanartSource.douban).isServerAcceptable,
      isFalse,
    );
    expect(const FanartQuery(limit: 49).isServerAcceptable, isFalse);
  });
}
