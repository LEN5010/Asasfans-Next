import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../domain/novel_repository.dart';
import 'novel_html.dart';

/// Adapter for the read-only novel archive served next to the dynamics API.
///
/// The wire contract follows the server's shared novel DTOs. Identity,
/// rating, pagination and the R18 visibility rule are checked strictly;
/// display fields degrade to empty values instead of failing the page.
class DynamicNovelRepository implements NovelRepository {
  DynamicNovelRepository(this._api, {required this.baseUrl});
  final PublicApiClient _api;
  final Uri baseUrl;

  static final _sourceTid = RegExp(r'^[1-9]\d{0,31}$');

  @override
  Future<NovelPage> search({
    NovelQuery query = const NovelQuery(),
    int offset = 0,
    RequestCancellation? cancellation,
  }) async {
    if (!query.isServerAcceptable || offset < 0) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final token = CancelToken();
    cancellation?.onCancel(token.cancel);
    final json = await _api.get(
      'novels',
      query: buildQuery(query, offset: offset),
      cancelToken: token,
    );
    return decodePage(json, baseUrl: baseUrl);
  }

  @override
  Future<NovelDetail> detail(
    String sourceTid, {
    RequestCancellation? cancellation,
  }) async {
    if (!_sourceTid.hasMatch(sourceTid)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final token = CancelToken();
    cancellation?.onCancel(token.cancel);
    try {
      final json = await _api.get('novels/$sourceTid', cancelToken: token);
      return decodeDetail(json, baseUrl: baseUrl);
    } on ApiFailure catch (failure) {
      // The id is validated above, so a 4xx here is the server's 404 for a
      // work outside the public catalogue.
      if (failure.kind == ApiFailureKind.invalidRequest) {
        throw const ApiFailure(ApiFailureKind.notFound);
      }
      rethrow;
    }
  }

  @override
  Future<NovelFacets> facets() async =>
      decodeFacets(await _api.get('novels/facets'));

  static Map<String, dynamic> buildQuery(NovelQuery query, {int offset = 0}) {
    final keyword = query.keyword.trim();
    return {
      if (keyword.isNotEmpty) 'q': keyword,
      if (keyword.isNotEmpty) 'scope': query.scope.name,
      if (query.characters.isNotEmpty)
        'character': (query.characters.map((c) => c.wire).toList()..sort())
            .join(','),
      'rating': query.rating.name,
      'sort': query.sort.name,
      'limit': query.limit,
      'offset': offset,
    };
  }

  static NovelPage decodePage(
    Map<String, dynamic> json, {
    required Uri baseUrl,
  }) {
    final items = json['items'];
    final total = json['total'];
    final offset = json['offset'];
    final limit = json['limit'];
    if (items is! List ||
        total is! int ||
        offset is! int ||
        limit is! int ||
        total < 0 ||
        offset < 0 ||
        limit < 1 ||
        items.length > limit ||
        items.length > (total - offset).clamp(0, total)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return NovelPage(
      items: List.unmodifiable(items.map((raw) => decodeSummary(raw, baseUrl))),
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  static NovelSummary decodeSummary(Object? raw, Uri baseUrl) {
    if (raw is! Map) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final id = raw['id'];
    final sourceTid = raw['sourceTid'];
    final rating = NovelRating.values
        .where((value) => value.name == raw['rating'])
        .firstOrNull;
    if (id is! String ||
        id.isEmpty ||
        sourceTid is! String ||
        !_sourceTid.hasMatch(sourceTid) ||
        rating == null) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    // R18 previews are never shown, even if a server regression sends them.
    final hidden = rating == NovelRating.nsfw;
    final images = raw['images'];
    return NovelSummary(
      id: id,
      sourceTid: sourceTid,
      title: _string(raw['title']),
      authorName: _string(raw['authorName']),
      rating: rating,
      characters: List.unmodifiable(_characters(raw['characters'])),
      charCount: _count(raw['charCount']),
      excerpt: hidden ? '' : _string(raw['excerpt']).trim(),
      images: List.unmodifiable(
        hidden || images is! List
            ? const <Uri>[]
            : images
                  .whereType<String>()
                  .map((src) => novelAssetUri(src, baseUrl))
                  .whereType<Uri>(),
      ),
      sourceUrl: _httpsUri(raw['sourceUrl']),
      createdAt: raw['createdAt'] is String
          ? DateTime.tryParse(raw['createdAt'] as String)
          : null,
    );
  }

  static NovelDetail decodeDetail(
    Map<String, dynamic> json, {
    required Uri baseUrl,
  }) {
    final summary = decodeSummary(json, baseUrl);
    final visible = json['contentVisible'];
    final html = json['contentHtml'];
    final links = json['externalLinks'];
    // An R18 work must arrive without text; anything else breaks the
    // contract this reader relies on to keep it hidden.
    if (visible is! bool ||
        html is! String ||
        links is! List ||
        (summary.isR18 && visible) ||
        (!visible && html.isNotEmpty)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final labels = _strings(json['warningLabels']);
    return NovelDetail(
      summary: summary,
      contentVisible: visible,
      blocks: visible
          ? novelBlocksFromHtml(html, baseUrl: baseUrl)
          : const <NovelBlock>[],
      warnings: List.unmodifiable(
        labels.isNotEmpty ? labels : _strings(json['warnings']),
      ),
      externalLinks: List.unmodifiable(
        links.map(_link).whereType<NovelExternalLink>(),
      ),
      primaryKind: json['primaryKind'] == 'external'
          ? NovelPrimaryKind.external
          : NovelPrimaryKind.main,
      externalCharCount: _count(json['externalCharCount']),
    );
  }

  static NovelFacets decodeFacets(Map<String, dynamic> json) {
    final total = json['total'];
    final ratings = json['byRating'];
    if (total is! int || total < 0 || ratings is! Map) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return NovelFacets(
      total: total,
      byRating: {
        for (final rating in NovelRating.values)
          rating: _count(ratings[rating.name]),
      },
    );
  }

  /// Links that cannot be opened safely are dropped rather than shown dead.
  static NovelExternalLink? _link(Object? raw) {
    if (raw is! Map) return null;
    final url = _httpsUri(raw['url']);
    if (url == null) return null;
    final label = _string(raw['label']);
    return NovelExternalLink(
      url: url,
      kind: raw['kind'] == 'source'
          ? NovelLinkKind.source
          : NovelLinkKind.external,
      label: label.isEmpty ? url.host : label,
    );
  }

  static String _string(Object? raw) => raw is String ? raw : '';

  static int _count(Object? raw) => raw is int && raw >= 0 ? raw : 0;

  static List<String> _strings(Object? raw) => raw is List
      ? raw.whereType<String>().where((value) => value.isNotEmpty).toList()
      : const [];

  /// Unknown tags are skipped so a new character never blanks the list.
  static List<NovelCharacter> _characters(Object? raw) => raw is! List
      ? const []
      : raw
            .map(
              (tag) => NovelCharacter.values
                  .where((value) => value.wire == tag)
                  .firstOrNull,
            )
            .whereType<NovelCharacter>()
            .toSet()
            .toList();

  static Uri? _httpsUri(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }
}
