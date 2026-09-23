import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/novels/data/dynamic_novel_repository.dart';
import 'package:asasfans_next/features/novels/domain/novel_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item({
  String sourceTid = '123456',
  String rating = 'sfw',
  String excerpt = '开头的几句话',
  List<Object?> images = const [],
}) => {
  'id': 'work-$sourceTid',
  'sourceTid': sourceTid,
  'sourceUrl': 'https://www.douban.com/group/topic/$sourceTid/',
  'title': '标题 $sourceTid',
  'authorName': '作者',
  'createdAt': '2021-05-10 18:22:54',
  'rating': rating,
  'characters': ['嘉然', '贝拉', '未知角色'],
  'charCount': 12345,
  'excerpt': excerpt,
  'images': images,
};

void main() {
  final base = Uri.parse('https://example.test/dynamics/api/');
  final hash = 'b' * 64;

  group('list', () {
    test('decodes items, identity and offset continuation', () {
      final page = DynamicNovelRepository.decodePage({
        'items': [
          _item(images: ['/api/novels/assets/$hash.jpg', 'javascript:x']),
          _item(sourceTid: '2'),
        ],
        'total': 30,
        'offset': 0,
        'limit': 2,
      }, baseUrl: base);
      expect(page.nextOffset, 2);
      final first = page.items.first;
      expect(first.sourceTid, '123456');
      expect(first.identity.value, '123456');
      expect(first.rating, NovelRating.sfw);
      expect(first.characters, [NovelCharacter.diana, NovelCharacter.bella]);
      expect(first.charCount, 12345);
      expect(first.excerpt, '开头的几句话');
      expect(first.createdAt, DateTime(2021, 5, 10, 18, 22, 54));
      expect(
        first.sourceUrl.toString(),
        'https://www.douban.com/group/topic/123456/',
      );
      expect(first.images.map((uri) => uri.toString()), [
        'https://example.test/dynamics/api/novels/assets/$hash.jpg',
      ]);
    });

    test('the last page has no next offset', () {
      final page = DynamicNovelRepository.decodePage({
        'items': [_item()],
        'total': 25,
        'offset': 24,
        'limit': 24,
      }, baseUrl: base);
      expect(page.nextOffset, isNull);
    });

    test('R18 items never carry a preview', () {
      final item = DynamicNovelRepository.decodeSummary(
        _item(
          rating: 'nsfw',
          excerpt: '不应显示',
          images: ['https://img.test/a.png'],
        ),
        base,
      );
      expect(item.isR18, isTrue);
      expect(item.excerpt, isEmpty);
      expect(item.images, isEmpty);
    });

    test('malformed envelopes and identities fail instead of emptying', () {
      final fails = throwsA(
        isA<ApiFailure>().having(
          (f) => f.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      );
      expect(
        () => DynamicNovelRepository.decodePage({
          'items': 'broken',
          'total': 0,
          'offset': 0,
          'limit': 24,
        }, baseUrl: base),
        fails,
      );
      expect(
        () => DynamicNovelRepository.decodePage({
          'items': [_item(), _item(sourceTid: '2')],
          'total': 1,
          'offset': 0,
          'limit': 24,
        }, baseUrl: base),
        fails,
      );
      expect(
        () => DynamicNovelRepository.decodeSummary(
          _item(sourceTid: '0123'),
          base,
        ),
        fails,
      );
      expect(
        () => DynamicNovelRepository.decodeSummary(
          _item(rating: 'unknown'),
          base,
        ),
        fails,
      );
    });

    test('builds only the parameters the server validates', () {
      expect(DynamicNovelRepository.buildQuery(const NovelQuery()), {
        'rating': 'sfw',
        'sort': 'newest',
        'limit': 24,
        'offset': 0,
      });
      expect(
        DynamicNovelRepository.buildQuery(
          const NovelQuery(
            keyword: ' 星 ',
            scope: NovelSearchScope.username,
            characters: {NovelCharacter.eileen, NovelCharacter.diana},
            rating: NovelRatingFilter.all,
            sort: NovelSort.longest,
          ),
          offset: 48,
        ),
        {
          'q': '星',
          'scope': 'username',
          'character': '乃琳,嘉然',
          'rating': 'all',
          'sort': 'longest',
          'limit': 24,
          'offset': 48,
        },
      );
    });
  });

  group('detail', () {
    test('a visible work decodes its text into blocks', () {
      final detail = DynamicNovelRepository.decodeDetail({
        ..._item(),
        'contentHtml': '<h1>序</h1><p>正文<br>第二行</p>',
        'contentVisible': true,
        'reading': null,
        'warnings': ['graphic_violence'],
        'warningLabels': ['血腥暴力'],
        'externalLinks': [
          {
            'url': 'https://www.douban.com/group/topic/123456/',
            'kind': 'source',
            'label': '豆瓣原帖',
          },
          {
            'url': 'http://insecure.test/doc',
            'kind': 'external',
            'label': 'insecure.test',
          },
          {
            'url': 'https://write.as/x',
            'kind': 'external',
            'label': 'Write.as',
          },
        ],
        'primaryKind': 'main',
        'primaryCharCount': 12000,
        'externalCharCount': 345,
      }, baseUrl: base);
      expect(detail.contentVisible, isTrue);
      expect(detail.blocks, const [
        NovelTextBlock.heading('序', 1),
        NovelTextBlock('正文\n第二行'),
      ]);
      expect(detail.warnings, ['血腥暴力']);
      expect(detail.externalLinks.map((l) => l.label), ['豆瓣原帖', 'Write.as']);
      expect(detail.externalLinks.first.kind, NovelLinkKind.source);
      expect(detail.externalCharCount, 345);
      expect(detail.primaryKind, NovelPrimaryKind.main);
    });

    test('an R18 work arrives with metadata, warnings and links only', () {
      final detail = DynamicNovelRepository.decodeDetail({
        ..._item(rating: 'nsfw', excerpt: ''),
        'contentHtml': '',
        'contentVisible': false,
        'reading': null,
        'warnings': ['sexual', 'custom'],
        'warningLabels': <String>[],
        'externalLinks': [
          {
            'url': 'https://shimo.im/docs/abc',
            'kind': 'external',
            'label': '石墨文档',
          },
        ],
        'primaryKind': 'external',
        'primaryCharCount': 0,
        'externalCharCount': 12345,
      }, baseUrl: base);
      expect(detail.contentVisible, isFalse);
      expect(detail.blocks, isEmpty);
      expect(detail.summary.isR18, isTrue);
      // Raw codes stand in when the server sends no labels.
      expect(detail.warnings, ['sexual', 'custom']);
      expect(detail.externalLinks.single.url.host, 'shimo.im');
      expect(detail.primaryKind, NovelPrimaryKind.external);
    });

    test('text for an R18 or hidden work breaks the contract', () {
      Map<String, dynamic> body({
        required String rating,
        required bool visible,
        required String html,
      }) => {
        ..._item(rating: rating, excerpt: ''),
        'contentHtml': html,
        'contentVisible': visible,
        'warnings': <String>[],
        'warningLabels': <String>[],
        'externalLinks': <Object>[],
        'primaryKind': 'main',
      };
      for (final json in [
        body(rating: 'nsfw', visible: true, html: ''),
        body(rating: 'nsfw', visible: false, html: '<p>泄露</p>'),
        body(rating: 'sfw', visible: false, html: '<p>正文</p>'),
        {...body(rating: 'sfw', visible: true, html: ''), 'contentVisible': 1},
      ]) {
        expect(
          () => DynamicNovelRepository.decodeDetail(json, baseUrl: base),
          throwsA(isA<ApiFailure>()),
        );
      }
    });
  });

  test('facets read the rating counts', () {
    final facets = DynamicNovelRepository.decodeFacets({
      'total': 10,
      'byCharacter': {'嘉然': 4, '贝拉': 3, '乃琳': 2},
      'byRating': {'sfw': 7, 'nsfw': 3},
    });
    expect(facets.count(NovelRatingFilter.all), 10);
    expect(facets.count(NovelRatingFilter.sfw), 7);
    expect(facets.count(NovelRatingFilter.nsfw), 3);
    expect(
      () => DynamicNovelRepository.decodeFacets({'total': 'x'}),
      throwsA(isA<ApiFailure>()),
    );
  });
}
