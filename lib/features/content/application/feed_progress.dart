import '../../../core/domain/content_identity.dart';

/// Source identity and opaque continuation progress, not protocol decoding.
/// A bounded run of empty/duplicate pages stops as an error, never a fake end.
class FeedProgress<T> {
  FeedProgress(this.identityOf);
  final ContentIdentity Function(T) identityOf;
  final _identities = <ContentIdentity>{};
  final _continuations = <Object>{};
  int _emptyPages = 0;

  void reset() {
    _identities.clear();
    _continuations.clear();
    _emptyPages = 0;
  }

  ({List<T> added, bool stalled}) accept(
    List<T> items, {
    required Object? continuation,
  }) {
    final added = items
        .where((item) => _identities.add(identityOf(item)))
        .toList();
    _emptyPages = added.isEmpty ? _emptyPages + 1 : 0;
    final repeated = continuation != null && !_continuations.add(continuation);
    return (
      added: List.unmodifiable(added),
      stalled: continuation != null && (repeated || _emptyPages >= 3),
    );
  }
}
