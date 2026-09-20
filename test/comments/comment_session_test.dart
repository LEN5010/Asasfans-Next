import 'dart:async';
import 'package:asasfans_next/app/bilibili_providers.dart';
import 'package:asasfans_next/features/account/application/account_controller.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:asasfans_next/features/comments/application/comment_providers.dart';
import 'package:asasfans_next/features/comments/domain/comments.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  test(
    'logout rebuilds comment dependencies and rejects the previous account response',
    () async {
      final account = AccountController(
        OfflineAuthGateway(),
        MemoryAccountVault()..value = accountSession(),
        MemoryLogoutIntent(),
        MemoryLoginCookies(),
      );
      await account.restore();
      final pending = Completer<Map<String, Object?>>();
      final gateways = <FixtureReadGateway>[];
      final container = ProviderContainer(
        overrides: [
          accountControllerProvider.overrideWith((ref) => account),
          biliReadGatewayProvider.overrideWith((ref) {
            ref.watch(accountSessionRevisionProvider);
            final gateway = FixtureReadGateway()
              ..respond = (_, _, _) => gateways.length == 1
                  ? pending.future
                  : Future.value(commentPagePayload(total: 0));
            gateways.add(gateway);
            return gateway;
          }),
        ],
      );
      addTearDown(container.dispose);
      final provider = commentControllerProvider(
        const CommentQuery(oid: fixtureAid),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final old = container.read(provider);
      await Future<void>.delayed(Duration.zero);
      final token = gateways.first.calls.single.cancellation;
      await account.logout();
      await Future<void>.delayed(Duration.zero);
      final current = container.read(provider);
      await Future<void>.delayed(Duration.zero);
      expect(current, same(container.read(provider)));
      expect(current, isNot(same(old)));
      expect(token!.isCancelled, isTrue);
      pending.complete(commentPagePayload(total: 1));
      await Future<void>.delayed(Duration.zero);
      expect(current.visible, isEmpty);
      expect(old.visible, isEmpty);
    },
  );
}
