import 'dart:async';

import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/rules/application/rules_controller.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:asasfans_next/features/rules/domain/rules_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements RulesRepository {
  final notifications = StreamController<int>.broadcast(sync: true);
  final reads = <Completer<RulesSnapshot>>[];
  @override
  Stream<int> get changes => notifications.stream;
  @override
  Future<RulesSnapshot> load() {
    final c = Completer<RulesSnapshot>();
    reads.add(c);
    return c.future;
  }

  @override
  Future<void> close() => notifications.close();
  @override
  Future<RuleChange> save(RuleDraft draft, {ContentRule? previous}) =>
      throw UnimplementedError();
  @override
  Future<RuleChange> remove(ContentRule rule) => throw UnimplementedError();
  @override
  Future<bool> undo(RuleChange change) => throw UnimplementedError();
  @override
  Future<void> setSubscriptionPriority(bool enabled) =>
      throw UnimplementedError();
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'rules are not considered ready before durable load and load failures do not reveal defaults',
    () async {
      final repository = _Repository();
      final subscriptions = StreamController<int>();
      final controller = RulesController(repository, subscriptions.stream);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
        await subscriptions.close();
      });
      expect(controller.state.ready, isFalse);
      repository.reads.first.completeError(
        const StorageFailure(StorageFailureKind.unavailable),
      );
      await tick();
      expect(controller.state.ready, isFalse);
      expect(controller.state.failure, isNotNull);
      final retry = controller.reload();
      repository.reads.last.complete(RulesSnapshot(rules: []));
      await retry;
      expect(controller.state.ready, isTrue);
    },
  );
  test(
    'bursty external writes are coalesced and continuous changes pause after one retry',
    () async {
      final repository = _Repository();
      final subscriptions = StreamController<int>.broadcast(sync: true);
      final controller = RulesController(repository, subscriptions.stream);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
        await subscriptions.close();
      });
      repository.notifications.add(1);
      subscriptions.add(2);
      repository.reads[0].complete(RulesSnapshot(rules: []));
      await tick();
      expect(repository.reads, hasLength(2));
      repository.notifications.add(3);
      repository.reads[1].complete(RulesSnapshot(rules: []));
      await tick();
      expect(repository.reads, hasLength(2));
      expect(controller.state.ready, isFalse);
      final reload = controller.reload();
      repository.reads[2].complete(RulesSnapshot(rules: []));
      await reload;
      expect(controller.state.ready, isTrue);
    },
  );
  test(
    'expiry and resume clocks change effective rules without deleting the saved rule',
    () async {
      var now = DateTime.utc(2026, 9, 21);
      final repository = _Repository();
      final subscriptions = StreamController<int>();
      final controller = RulesController(
        repository,
        subscriptions.stream,
        clock: () => now,
      );
      addTearDown(() async {
        controller.dispose();
        await repository.close();
        await subscriptions.close();
      });
      final rule = ContentRule(
        id: '1' * 32,
        draft: RuleDraft(
          kind: RuleKind.word,
          value: 'word',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
        createdAt: now,
        updatedAt: now,
        changeToken: '2' * 32,
      );
      repository.reads.first.complete(RulesSnapshot(rules: [rule]));
      await tick();
      final before = controller.state.epoch;
      now = now.add(const Duration(hours: 2));
      controller.reconsiderExpiry();
      expect(controller.state.epoch, before + 1);
      expect(controller.state.snapshot!.rules, hasLength(1));
      expect(
        controller.state.snapshot!.rules.single.activeAt(controller.state.now),
        isFalse,
      );
    },
  );
  test(
    'disposed controller ignores a late read and closes pending readiness with a typed error',
    () async {
      final repository = _Repository();
      final subscriptions = StreamController<int>();
      final controller = RulesController(repository, subscriptions.stream);
      final future = controller.ready();
      controller.dispose();
      repository.reads.first.complete(RulesSnapshot(rules: []));
      await expectLater(future, throwsA(isA<StorageFailure>()));
      await repository.close();
      await subscriptions.close();
    },
  );
}
