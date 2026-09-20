import '../domain/fanart_repository.dart';

/// Keep every draft selection within the public API's accepted combinations.
abstract final class FanartFilterRules {
  static FanartQuery contentType(FanartQuery query, FanartContentType value) =>
      query.copyWith(
        contentType: value,
        sort: value != FanartContentType.video && query.usesMetricSort
            ? FanartSort.newest
            : query.sort,
      );

  static FanartQuery sort(FanartQuery query, FanartSort value) {
    final metric = value == FanartSort.views || value == FanartSort.favorites;
    return query.copyWith(
      sort: value,
      contentType: metric ? FanartContentType.video : query.contentType,
      source: metric && query.source == FanartSource.douban
          ? FanartSource.bilibili
          : query.source,
    );
  }

  static FanartQuery source(FanartQuery query, FanartSource value) =>
      query.copyWith(
        source: value,
        sort: value == FanartSource.douban && query.usesMetricSort
            ? FanartSort.newest
            : query.sort,
      );

  static FanartQuery reset(FanartQuery query) =>
      FanartQuery(keyword: query.keyword, limit: query.limit);

  static int count(FanartQuery query) =>
      query.characters.length +
      (query.contentType == FanartContentType.all ? 0 : 1) +
      (query.category == FanartCategory.all ? 0 : 1) +
      (query.source == FanartSource.all ? 0 : 1) +
      (query.kind == FanartKind.fanart ? 0 : 1) +
      (query.sort == FanartSort.newest ? 0 : 1);
}
