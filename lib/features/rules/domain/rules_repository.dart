import 'content_rules.dart';

abstract interface class RulesRepository {
  Stream<int> get changes;
  Future<RulesSnapshot> load();
  Future<RuleChange> save(RuleDraft draft, {ContentRule? previous});
  Future<RuleChange> remove(ContentRule rule);

  /// Compare-and-swap undo: never overwrites a subsequent user edit.
  Future<bool> undo(RuleChange change);
  Future<void> setSubscriptionPriority(bool enabled);
  Future<void> close();
}
