import '../../../core/network/api_failure.dart';
import '../../content/domain/fanart_repository.dart';
import '../domain/content_rules.dart';
import 'feed_visibility.dart';
import 'rules_controller.dart';

class VisibleRandom {
  const VisibleRandom({this.item, this.filtered = false});
  final FanartItem? item;
  final bool filtered;
}

/// Bounded rejection sampling. A blocked draw is not proof of an empty source.
Future<VisibleRandom> drawVisibleFanart(
  FanartRepository repository,
  RulesController rules, {
  required FanartQuery query,
  required RequestCancellation cancellation,
}) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    await rules.ready();
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    final item = await repository.random(
      query: query,
      cancellation: cancellation,
    );
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (item == null) return const VisibleRandom();
    final policy = await rules.ready();
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (!ContentRuleEvaluator(
      policy.snapshot!,
      policy.now,
    ).evaluate(RuleSubjects.fanart(item)).blocked) {
      return VisibleRandom(item: item);
    }
  }
  return const VisibleRandom(filtered: true);
}
