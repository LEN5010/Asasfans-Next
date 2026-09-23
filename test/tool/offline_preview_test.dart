import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/preview/offline_environment.dart';
import '../helpers/account_fixture.dart';
import '../helpers/sqlite_fixture.dart';

void main() {
  test('preview cannot create a network client', () {
    expect(
      () => OfflinePreviewHttpOverrides().createHttpClient(null),
      throwsStateError,
    );
  });

  test(
    'preview isolates personal storage, credentials and external opens',
    () async {
      final container = ProviderContainer(overrides: offlinePreviewOverrides());
      addTearDown(container.dispose);
      expect(container.read(localDatabaseProvider), isA<MemoryLocalDatabase>());
      expect(container.read(biliVaultProvider), isA<MemoryAccountVault>());
      expect(await container.read(biliVaultProvider).stored(), isFalse);
      expect(
        container.read(biliLoginCookiesProvider),
        isA<MemoryLoginCookies>(),
      );
      expect(
        await container
            .read(externalLinkServiceProvider)
            .open(Uri.parse('https://example.org')),
        isFalse,
      );
    },
  );

  testWidgets(
    'native preview fixtures exercise all main branches without production data',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlinePreviewOverrides(),
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['内容', '日历', '我的', '今日']) {
        await tester.tap(
          find.descendant(
            of: find.byType(AppSidebar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.tap(
        find.descendant(of: find.byType(AppSidebar), matching: find.text('工具')),
      );
      await tester.pumpAndSettle();
      expect(find.text('录音棚'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
