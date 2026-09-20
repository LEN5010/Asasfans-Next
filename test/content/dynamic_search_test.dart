import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/data/dynamic_post_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Uri.parse('https://example.test/dynamics/api/');

  group('query validation', () {
    test('a member filter must use the uid: form the server accepts', () {
      expect(
        const DynamicQuery(memberId: 'uid:703007996').isServerAcceptable,
        isTrue,
      );
      expect(
        const DynamicQuery(memberId: '703007996').isServerAcceptable,
        isFalse,
      );
      expect(const DynamicQuery(memberId: 'uid:').isServerAcceptable, isFalse);
    });

    test('an inverted or empty date range is rejected locally', () {
      final from = DateTime.utc(2022, 5, 1);
      final to = DateTime.utc(2021, 5, 1);
      expect(DynamicQuery(from: from, to: to).isServerAcceptable, isFalse);
      expect(DynamicQuery(from: from, to: from).isServerAcceptable, isFalse);
      expect(DynamicQuery(from: to, to: from).isServerAcceptable, isTrue);
    });

    test('limit and keyword honour the server bounds', () {
      expect(const DynamicQuery(limit: 50).isServerAcceptable, isTrue);
      expect(const DynamicQuery(limit: 51).isServerAcceptable, isFalse);
      expect(const DynamicQuery(limit: 0).isServerAcceptable, isFalse);
      expect(DynamicQuery(keyword: 'a' * 201).isServerAcceptable, isFalse);
    });
  });

  test('sends dates as calendar days, not instants', () {
    final query = DynamicPostRepository.buildSearchQuery(
      DynamicQuery(
        keyword: '  生日  ',
        memberId: 'uid:703007996',
        type: DynamicType.image,
        from: DateTime.utc(2021, 8, 6),
        to: DateTime.utc(2021, 8, 16),
        sort: DynamicSort.likes,
        limit: 50,
      ),
      cursor: 'c1',
    );

    expect(query['q'], '生日');
    expect(query['member'], 'uid:703007996');
    expect(query['type'], 'image');
    expect(query['from'], '2021-08-06');
    expect(query['to'], '2021-08-16');
    expect(query['sort'], 'likes');
    expect(query['limit'], 50);
    expect(query['cursor'], 'c1');
  });

  test('omits absent filters rather than sending empty values', () {
    final query = DynamicPostRepository.buildSearchQuery(const DynamicQuery());
    expect(query.containsKey('q'), isFalse);
    expect(query.containsKey('member'), isFalse);
    expect(query.containsKey('type'), isFalse);
    expect(query.containsKey('from'), isFalse);
    expect(query.containsKey('cursor'), isFalse);
  });

  test('decodes a page and preserves both cursors', () {
    final page = DynamicPostRepository.decodeSearch({
      'items': [
        {'dynamicId': '1', 'contentText': '正文'},
      ],
      'nextCursor': 'n1',
      'prevCursor': 'p1',
      'total': 4213,
    }, baseUrl: base);

    expect(page.items, hasLength(1));
    expect(page.nextCursor, 'n1');
    expect(page.prevCursor, 'p1');
    expect(page.total, 4213);
  });

  test('a null next cursor means the end of the list', () {
    final page = DynamicPostRepository.decodeSearch({
      'items': <Object?>[],
      'nextCursor': null,
      'prevCursor': null,
    }, baseUrl: base);

    expect(page.nextCursor, isNull);
    expect(page.items, isEmpty);
  });

  test('a malformed page is not treated as a successful empty page', () {
    expect(
      () => DynamicPostRepository.decodeSearch({
        'items': 'broken',
      }, baseUrl: base),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => DynamicPostRepository.decodeSearch({
        'items': <Object?>[],
        'nextCursor': '',
      }, baseUrl: base),
      throwsA(isA<ApiFailure>()),
    );
  });
}
