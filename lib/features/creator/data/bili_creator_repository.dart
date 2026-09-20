import '../../../core/bilibili/bili_metadata_client.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/content_identity.dart';
import '../../../core/network/api_failure.dart';
import '../domain/creator_repository.dart';

class BiliCreatorRepository implements CreatorRepository {
  BiliCreatorRepository(this._gateway);
  final BiliReadGateway _gateway;
  @override
  Future<CreatorProfile> profile(
    String mid, {
    RequestCancellation? cancellation,
  }) async {
    if (!validBilibiliMid(mid)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final data = await _gateway.get(
      BiliReadEndpoint.card,
      parameters: {'mid': mid, 'photo': 'true'},
      cancellation: cancellation,
    );
    return decodeProfile(data, mid);
  }

  @override
  Future<CreatorArchivePage> archives(
    CreatorArchiveQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    if (!query.valid || page < 1 || page > 100000) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final data = await _gateway.get(
      BiliReadEndpoint.archives,
      parameters: {
        'mid': query.mid,
        'pn': '$page',
        'ps': '${query.pageSize}',
        'tid': '0',
        'order': query.order.wire,
        'keyword': query.keyword.trim(),
      },
      cancellation: cancellation,
    );
    return decodeArchives(data, query, page);
  }

  static CreatorProfile decodeProfile(
    Map<String, Object?> data,
    String expectedMid,
  ) {
    final card = _map(data['card']);
    final mid = _mid(card['mid']);
    if (mid != expectedMid) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final name = _text(card['name'], 1000);
    if (name.trim().isEmpty) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final space = card['space'] is Map
        ? _map(card['space'])
        : <String, Object?>{};
    final official = card['Official'] is Map
        ? _map(card['Official'])
        : <String, Object?>{};
    return CreatorProfile(
      mid: mid,
      name: name,
      signature: _text(card['sign'], 10000),
      avatar: _uri(card['face']),
      banner: _uri(space['l_img']),
      official: _text(official['title'], 2000),
      followers: _count(data['follower']) ?? _count(card['fans']),
      following: _count(card['attention']) ?? _count(card['friend']),
      archiveCount: _count(data['archive_count']),
      likes: _count(data['like_num']),
    );
  }

  static CreatorArchivePage decodeArchives(
    Map<String, Object?> data,
    CreatorArchiveQuery query,
    int requestedPage,
  ) {
    final list = _map(data['list']);
    final info = _map(data['page']);
    final page = _count(info['pn']);
    final size = _count(info['ps']);
    final total = _count(info['count']);
    final rows = list['vlist'];
    if (page != requestedPage ||
        size != query.pageSize ||
        total == null ||
        rows is! List ||
        rows.length > query.pageSize ||
        (rows.isNotEmpty &&
            (requestedPage - 1) * query.pageSize + rows.length > total) ||
        (rows.isEmpty && (requestedPage - 1) * query.pageSize < total)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final expected = (total - (requestedPage - 1) * query.pageSize).clamp(
      0,
      query.pageSize,
    );
    if (rows.length != expected) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final partitions = list['tlist'] is Map
        ? _map(list['tlist'])
        : <String, Object?>{};
    final items = <VideoSummary>[];
    final seen = <String>{};
    for (final value in rows) {
      final row = _map(value);
      final bvid = _text(row['bvid'], 12);
      if (!validBvid(bvid)) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final title = _text(row['title'], 10000);
      if (title.trim().isEmpty) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final mid = row['mid'] == null ? '' : _mid(row['mid']);
      final typeId = _count(row['typeid']);
      final partition = partitions['$typeId'];
      if (!seen.add(bvid)) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      items.add(
        VideoSummary(
          identity: ContentIdentity(
            source: ContentSource.bilibiliVideo,
            value: bvid,
          ),
          title: title,
          // Collaborations can have a different actual owner. Never replace the
          // returned MID with the profile currently being browsed.
          creatorId: mid,
          creatorName: _text(row['author'], 1000),
          description: _text(row['description'], 100000),
          coverUrl: _uri(row['pic']),
          category: partition is Map ? _text(partition['name'], 1000) : '',
          tags: null,
          publishedAt: _date(row['created']),
          duration: _duration(row['length']),
          viewCount: row['hide_click'] == true ? null : _count(row['play']),
        ),
      );
    }
    return CreatorArchivePage(
      items: items,
      page: requestedPage,
      total: total,
      hasMore: requestedPage * query.pageSize < total,
    );
  }

  static Map<String, Object?> _map(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return Map<String, Object?>.from(raw);
  }

  static String _text(Object? raw, int limit) {
    if (raw == null) return '';
    if (raw is! String || raw.length > limit || raw.contains('\u0000')) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return raw;
  }

  static String _mid(Object? raw) {
    final value = raw is String
        ? raw
        : raw is int
        ? '$raw'
        : '';
    if (!validBilibiliMid(value)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return value;
  }

  static int? _count(Object? raw) {
    final value = raw is int
        ? raw
        : raw is String && RegExp(r'^\d+$').hasMatch(raw)
        ? int.tryParse(raw)
        : null;
    return value != null && value >= 0 ? value : null;
  }

  static DateTime? _date(Object? raw) {
    final seconds = _count(raw);
    return seconds == null || seconds == 0 || seconds > 253402300799
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static Duration? _duration(Object? raw) {
    if (raw is! String) return null;
    final values = raw.split(':');
    if (values.length < 2 ||
        values.length > 3 ||
        values.any((value) => !RegExp(r'^\d{1,5}$').hasMatch(value))) {
      return null;
    }
    final parts = values.map(int.parse).toList();
    if (parts.last >= 60 || (parts.length == 3 && parts[1] >= 60)) return null;
    final seconds = parts.fold<int>(0, (total, part) => total * 60 + part);
    return seconds > 0 && seconds <= 2147483647
        ? Duration(seconds: seconds)
        : null;
  }

  static Uri? _uri(Object? raw) {
    if (raw is! String || raw.length > 4096) return null;
    final uri = Uri.tryParse(raw.startsWith('//') ? 'https:$raw' : raw);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.replace(scheme: 'https');
  }
}
