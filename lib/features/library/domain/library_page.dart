import 'library_models.dart';

enum LibraryListKind { collection, later, history }

class LibraryQuery {
  const LibraryQuery.collection(String id)
    : kind = LibraryListKind.collection,
      folderId = id,
      pendingOnly = false,
      action = null;
  const LibraryQuery.later({this.pendingOnly = true})
    : kind = LibraryListKind.later,
      folderId = null,
      action = null;
  const LibraryQuery.history({this.action})
    : kind = LibraryListKind.history,
      folderId = null,
      pendingOnly = false;

  final LibraryListKind kind;
  final String? folderId;
  final bool pendingOnly;
  final HistoryAction? action;

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      kind == other.kind &&
      folderId == other.folderId &&
      pendingOnly == other.pendingOnly &&
      action == other.action;
  @override
  int get hashCode => Object.hash(kind, folderId, pendingOnly, action);
}

/// In-memory continuation, bound to a store, committed revision and query.
/// Never persisted or sent to a public content API.
class LibraryCursor {
  LibraryCursor({
    required this.storeId,
    required this.revision,
    required this.query,
    required List<Object?> key,
  }) : key = List.unmodifiable(key);
  final String storeId;
  final int revision;
  final Object query;
  final List<Object?> key;
}

class LibraryPage<T> {
  LibraryPage({required List<T> items, this.next})
    : items = List.unmodifiable(items);
  final List<T> items;
  final LibraryCursor? next;
}
