import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/creator/data/bili_creator_repository.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _row({String id = 'BV0000000001', Object mid = '456'}) => {
  'bvid': id,
  'title': '合作投稿',
  'mid': mid,
  'author': '合作作者',
  'pic': '//i0.hdslb.com/cover.jpg',
  'created': 1702204169,
  'length': '1:02:03',
  'play': '--',
  'typeid': 27,
};
Map<String, Object?> _page(
  List<Object> rows, {
  int page = 1,
  int size = 30,
  int? total,
}) => {
  'list': {
    'vlist': rows,
    'tlist': {
      '27': {'name': '综合'},
    },
  },
  'page': {'pn': page, 'ps': size, 'count': total ?? rows.length},
};

class _Gateway implements BiliReadGateway {
  BiliReadEndpoint? endpoint;
  Map<String, String>? parameters;
  @override
  Future<Map<String, Object?>> get(
    BiliReadEndpoint endpoint, {
    Map<String, String> parameters = const {},
    RequestCancellation? cancellation,
  }) async {
    this.endpoint = endpoint;
    this.parameters = parameters;
    return _page([]);
  }
}

void main() {
  const query = CreatorArchiveQuery(mid: '123');
  test('card binds requested MID, large string IDs and unknown counts', () {
    const mid = '18446744073709551615';
    final result = BiliCreatorRepository.decodeProfile({
      'card': {
        'mid': mid,
        'name': '作者',
        'sign': '简介',
        'face': '//i0.hdslb.com/avatar.jpg',
        'Official': {'title': '认证'},
      },
    }, mid);
    expect(result.mid, mid);
    expect(result.followers, isNull);
    expect(result.avatar?.scheme, 'https');
    expect(result.official, '认证');
    for (final bad in [123.0, '0', '00123', '123456789012345678901', '456']) {
      expect(
        () => BiliCreatorRepository.decodeProfile({
          'card': {'mid': bad, 'name': 'x'},
        }, '123'),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test(
    'coauthors retain actual ownership; tags and hidden stats stay unknown',
    () {
      final item = BiliCreatorRepository.decodeArchives(
        _page([_row()]),
        query,
        1,
      ).items.single;
      expect(item.creatorId, '456');
      expect(item.creatorName, '合作作者');
      expect(item.tags, isNull);
      expect(item.category, '综合');
      expect(item.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(item.viewCount, isNull);
      expect(item.coverUrl?.scheme, 'https');
      final noMid = _row()..remove('mid');
      final hidden = {..._row(), 'hide_click': true, 'play': 10};
      expect(
        BiliCreatorRepository.decodeArchives(
          _page([noMid]),
          query,
          1,
        ).items.single.creatorId,
        '',
      );
      expect(
        BiliCreatorRepository.decodeArchives(
          _page([hidden]),
          query,
          1,
        ).items.single.viewCount,
        isNull,
      );
    },
  );
  test(
    'empty final slot with remaining count, short middle and duplicate rows fail',
    () {
      for (final fixture in [
        _page([], page: 2, total: 31),
        _page([_row()], total: 31),
        _page([_row(), _row()]),
        _page([_row(id: 'bad')]),
        _page([_row()], size: 50),
        _page([_row()], total: 0),
      ]) {
        final requestedPage = (fixture['page'] as Map)['pn'] as int;
        expect(
          () => BiliCreatorRepository.decodeArchives(
            fixture,
            query,
            requestedPage,
          ),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );
  test(
    'zero archives and last partial page are valid; terminal page has no continuation',
    () {
      expect(
        BiliCreatorRepository.decodeArchives(_page([]), query, 1).hasMore,
        isFalse,
      );
      final last = BiliCreatorRepository.decodeArchives(
        _page([_row()], page: 2, total: 31),
        query,
        2,
      );
      expect(last.hasMore, isFalse);
      expect(last.page, 2);
      final first = BiliCreatorRepository.decodeArchives(
        _page(
          List.generate(
            30,
            (i) => _row(id: 'BV${i.toString().padLeft(10, '0')}'),
          ),
          total: 31,
        ),
        query,
        1,
      );
      expect(first.hasMore, isTrue);
    },
  );
  test(
    'repository validates locally and sends only documented archive parameters',
    () async {
      final gateway = _Gateway();
      final repository = BiliCreatorRepository(gateway);
      await expectLater(
        repository.profile('123/../'),
        throwsA(isA<ApiFailure>()),
      );
      expect(gateway.endpoint, isNull);
      await expectLater(
        repository.archives(
          const CreatorArchiveQuery(mid: '123', keyword: 'a\nb'),
        ),
        throwsA(isA<ApiFailure>()),
      );
      await repository.archives(
        query.copyWith(
          keyword: '  嘉然  ',
          order: CreatorArchiveOrder.mostFavorited,
        ),
      );
      expect(gateway.endpoint, BiliReadEndpoint.archives);
      expect(gateway.parameters, {
        'mid': '123',
        'pn': '1',
        'ps': '30',
        'tid': '0',
        'keyword': '嘉然',
        'order': 'stow',
      });
    },
  );
}
