import '../../../core/domain/content_identity.dart';
import '../../../core/domain/request_cancellation.dart';

export '../../../core/domain/request_cancellation.dart';

/// Character tags the novel archive filters by. Selecting several narrows the
/// list to works tagged with all of them.
enum NovelCharacter {
  diana('嘉然'),
  bella('贝拉'),
  eileen('乃琳');

  const NovelCharacter(this.wire);
  final String wire;
}

enum NovelRating { sfw, nsfw }

enum NovelRatingFilter {
  sfw('全年龄'),
  all('全部'),
  nsfw('R18');

  const NovelRatingFilter(this.label);
  final String label;
}

enum NovelSort {
  newest('最新发布'),
  oldest('最早发布'),
  longest('字数最多');

  const NovelSort(this.label);
  final String label;
}

enum NovelSearchScope {
  all('全部'),
  title('标题'),
  content('正文'),
  username('作者');

  const NovelSearchScope(this.label);
  final String label;
}

class NovelQuery {
  const NovelQuery({
    this.keyword = '',
    this.scope = NovelSearchScope.all,
    this.characters = const {},
    this.rating = NovelRatingFilter.sfw,
    this.sort = NovelSort.newest,
    this.limit = 24,
  });

  final String keyword;
  final NovelSearchScope scope;
  final Set<NovelCharacter> characters;
  final NovelRatingFilter rating;
  final NovelSort sort;
  final int limit;

  bool get isServerAcceptable =>
      limit >= 1 && limit <= 48 && keyword.length <= 200;

  NovelQuery copyWith({
    String? keyword,
    NovelSearchScope? scope,
    Set<NovelCharacter>? characters,
    NovelRatingFilter? rating,
    NovelSort? sort,
    int? limit,
  }) => NovelQuery(
    keyword: keyword ?? this.keyword,
    scope: scope ?? this.scope,
    characters: characters ?? this.characters,
    rating: rating ?? this.rating,
    sort: sort ?? this.sort,
    limit: limit ?? this.limit,
  );

  @override
  bool operator ==(Object other) =>
      other is NovelQuery &&
      other.keyword == keyword &&
      other.scope == scope &&
      other.rating == rating &&
      other.sort == sort &&
      other.limit == limit &&
      other.characters.length == characters.length &&
      other.characters.containsAll(characters);

  @override
  int get hashCode => Object.hash(
    keyword,
    scope,
    rating,
    sort,
    limit,
    Object.hashAllUnordered(characters),
  );
}

class NovelSummary {
  const NovelSummary({
    required this.id,
    required this.sourceTid,
    required this.title,
    required this.authorName,
    required this.rating,
    required this.characters,
    required this.charCount,
    required this.excerpt,
    required this.images,
    this.sourceUrl,
    this.createdAt,
  });

  final String id;

  /// The Douban topic id. It is the stable identity and the detail route key.
  final String sourceTid;
  final String title;
  final String authorName;
  final NovelRating rating;
  final List<NovelCharacter> characters;

  /// Includes collected external documents, so it can exceed the main text.
  final int charCount;

  /// Always empty for R18 works: the archive never serves their text.
  final String excerpt;
  final List<Uri> images;
  final Uri? sourceUrl;

  /// Archive wall-clock time on the Shanghai calendar, without a zone.
  final DateTime? createdAt;

  bool get isR18 => rating == NovelRating.nsfw;

  ContentIdentity get identity =>
      ContentIdentity(source: ContentSource.doubanTopic, value: sourceTid);
}

class NovelPage {
  const NovelPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<NovelSummary> items;
  final int total;
  final int offset;
  final int limit;

  /// Offset of the following page, or null once the total is covered.
  int? get nextOffset {
    final next = offset + items.length;
    return next < total ? next : null;
  }
}

enum NovelLinkKind { source, external }

class NovelExternalLink {
  const NovelExternalLink({
    required this.url,
    required this.kind,
    required this.label,
  });

  final Uri url;
  final NovelLinkKind kind;
  final String label;
}

/// Where the main text lives: the Douban post itself or an external document
/// the post points to.
enum NovelPrimaryKind { main, external }

class NovelDetail {
  const NovelDetail({
    required this.summary,
    required this.contentVisible,
    required this.blocks,
    required this.warnings,
    required this.externalLinks,
    required this.primaryKind,
    required this.externalCharCount,
  });

  final NovelSummary summary;

  /// False for R18 works; [blocks] is then empty and only metadata is shown.
  final bool contentVisible;
  final List<NovelBlock> blocks;

  /// Display labels for content warnings.
  final List<String> warnings;
  final List<NovelExternalLink> externalLinks;
  final NovelPrimaryKind primaryKind;
  final int externalCharCount;
}

/// Reading layout units derived from the archive's simplified HTML.
sealed class NovelBlock {
  const NovelBlock();
}

enum NovelTextStyle { paragraph, heading, quote, preformatted }

class NovelTextBlock extends NovelBlock {
  const NovelTextBlock(this.text, {this.style = NovelTextStyle.paragraph})
    : level = 0;
  const NovelTextBlock.heading(this.text, this.level)
    : style = NovelTextStyle.heading;

  final String text;
  final NovelTextStyle style;

  /// Heading level 1–6; zero for every other style.
  final int level;

  @override
  bool operator ==(Object other) =>
      other is NovelTextBlock &&
      other.text == text &&
      other.style == style &&
      other.level == level;

  @override
  int get hashCode => Object.hash(text, style, level);

  @override
  String toString() => 'NovelTextBlock(${style.name}$level, $text)';
}

class NovelImageBlock extends NovelBlock {
  const NovelImageBlock(this.url, {this.alt = ''});
  final Uri url;
  final String alt;

  @override
  bool operator ==(Object other) =>
      other is NovelImageBlock && other.url == url && other.alt == alt;

  @override
  int get hashCode => Object.hash(url, alt);

  @override
  String toString() => 'NovelImageBlock($url)';
}

class NovelDividerBlock extends NovelBlock {
  const NovelDividerBlock();

  @override
  bool operator ==(Object other) => other is NovelDividerBlock;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NovelDividerBlock()';
}

class NovelFacets {
  const NovelFacets({required this.total, required this.byRating});
  final int total;
  final Map<NovelRating, int> byRating;

  int count(NovelRatingFilter filter) => switch (filter) {
    NovelRatingFilter.all => total,
    NovelRatingFilter.sfw => byRating[NovelRating.sfw] ?? 0,
    NovelRatingFilter.nsfw => byRating[NovelRating.nsfw] ?? 0,
  };
}

abstract interface class NovelRepository {
  Future<NovelPage> search({
    NovelQuery query = const NovelQuery(),
    int offset = 0,
    RequestCancellation? cancellation,
  });

  /// One work by its Douban topic id. R18 works come back without text.
  Future<NovelDetail> detail(
    String sourceTid, {
    RequestCancellation? cancellation,
  });

  /// Archive-wide counts, independent of the current filters.
  Future<NovelFacets> facets();
}
