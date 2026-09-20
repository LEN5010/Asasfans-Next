import '../../../core/network/api_failure.dart';
import '../../../core/domain/video_summary.dart';
import '../../library/domain/library_models.dart';

export '../../../core/domain/video_summary.dart';

class SubscriptionRoster {
  SubscriptionRoster({
    required this.storeId,
    required this.revision,
    required List<LocalSubscription> creators,
  }) : creators = List.unmodifiable(creators);
  final String storeId;
  final int revision;
  final List<LocalSubscription> creators;
}

abstract interface class SubscriptionUpdateStore {
  /// A small metadata inventory for merging, not a UI full-content query.
  Future<SubscriptionRoster> roster();
  Future<void> checkRoster(SubscriptionRoster roster);
  Future<Map<String, bool>> readStates(Iterable<String> bvids);
  Future<void> mark(Iterable<String> bvids, {required bool read});
  Stream<int> get changes;
  Future<void> close();
}

class SubscriptionIssue {
  const SubscriptionIssue(this.creator, this.failure);
  final LocalSubscription creator;
  final ApiFailure failure;
}

class SubscriptionSlice {
  SubscriptionSlice({
    required List<VideoSummary> items,
    required List<SubscriptionIssue> issues,
    required this.hasMore,
    required this.checkedCreators,
    required this.totalCreators,
    this.pause,
  }) : items = List.unmodifiable(items),
       issues = List.unmodifiable(issues);
  final List<VideoSummary> items;
  final List<SubscriptionIssue> issues;
  final bool hasMore;
  final int checkedCreators;
  final int totalCreators;

  /// Shared 429 cooldown stops the entire batch without dropping other heads.
  final ApiFailure? pause;
}
