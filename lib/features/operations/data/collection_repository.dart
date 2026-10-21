import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../domain/fanart_collection.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(publicApiClientProvider)),
);

final collectionProvider = FutureProvider.autoDispose
    .family<FanartCollection, String>(
      (ref, id) => ref.watch(collectionRepositoryProvider).get(id),
    );

class CollectionRepository {
  const CollectionRepository(this._api);
  final PublicApiClient _api;

  Future<FanartCollection> get(String id) async {
    try {
      return decode(
        await _api.get('app/collections/${Uri.encodeComponent(id)}'),
      );
    } on ApiFailure catch (error) {
      if (error.kind == ApiFailureKind.invalidRequest) {
        throw const ApiFailure(ApiFailureKind.notFound);
      }
      rethrow;
    }
  }

  static FanartCollection decode(Map<String, dynamic> json) {
    try {
      return FanartCollection(
        id: json['id'] as String,
        title: json['title'] as String,
        dates: json['dates'] as String,
        venue: json['venue'] as String,
        sourceUrl: _uri(json['sourceUrl']),
        sourceAuthor: json['sourceAuthor'] as String,
        groups: List<String>.from(json['groups'] as List),
        entries: [
          for (final entry in json['entries'] as List)
            FanartCollectionEntry(
              id: entry['id'] as String,
              title: entry['title'] as String,
              summary: entry['summary'] as String,
              author: entry['author'] as String,
              authorUid: entry['authorUid'] as String?,
              sourceUrl: _uri(entry['sourceUrl']),
              groups: List<String>.from(entry['groups'] as List),
              images: [for (final url in entry['images'] as List) _uri(url)],
              previews: [
                for (final preview in (entry['previews'] as List? ?? const []))
                  FanartCollectionPreview(
                    url: _uri(preview['url']),
                    groups: List<String>.from(preview['groups'] as List),
                  ),
              ],
              isVideo: entry['contentType'] == 'video',
            ),
        ],
      );
    } on TypeError {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
  }

  static Uri _uri(Object? value) {
    final uri = Uri.parse(value as String);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Expected HTTPS URL');
    }
    return uri;
  }
}
