import '../../../core/domain/content_identity.dart';

/// Local personal data is independent of Bilibili follows and site accounts.
/// A persistent implementation is gated on the Android legacy import design.
abstract interface class LibraryRepository {
  Stream<Set<ContentIdentity>> watchSavedItems();
  Future<void> save(ContentIdentity identity);
  Future<void> remove(ContentIdentity identity);
}
