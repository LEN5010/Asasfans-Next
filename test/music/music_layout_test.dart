import 'dart:async';

import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/music/application/music_audio_handler.dart';
import 'package:asasfans_next/features/music/application/music_providers.dart';
import 'package:asasfans_next/features/music/data/music_catalog_repository.dart';
import 'package:asasfans_next/features/music/data/music_stream_repository.dart';
import 'package:asasfans_next/features/music/domain/music_track.dart';
import 'package:asasfans_next/features/music/presentation/music_favorites_page.dart';
import 'package:asasfans_next/features/music/presentation/music_page.dart';
import 'package:asasfans_next/features/music/presentation/music_player_page.dart';
import 'package:asasfans_next/features/music/presentation/music_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixture.dart';

final _track = MusicTrack(
  id: '123',
  date: DateTime(2026, 10, 15),
  title: '带着很长歌名的五人合唱歌回',
  members: const ['嘉然', '乃琳', '贝拉', '心宜', '思诺'],
  duration: const Duration(minutes: 5),
  status: 'Live',
);

/// Metadata only: never initializes AudioPlayer, AudioService or a network call.
class _QueueFixture extends MusicAudioHandler {
  _QueueFixture() : super(MusicStreamRepository(Dio()));
  @override
  MusicTrack get current => _track;
  @override
  List<MusicTrack> get tracks => [_track];
  @override
  int get index => 0;
}

Widget _app(Widget home) => ProviderScope(
  // A fresh scope and navigator for each pumped app.
  key: UniqueKey(),
  overrides: [
    ...offlineLibrary(),
    musicCatalogProvider.overrideWith((ref) async => MusicCatalog([_track])),
    musicAudioHandlerProvider.overrideWith((ref) => _QueueFixture()),
    memberAvatarsProvider.overrideWithValue(const {}),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  testWidgets('music page, favorites and player fit 360 wide at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const MusicPage()));
    await tester.pumpAndSettle();
    expect(find.text('搜索歌名'), findsOneWidget);
    expect(find.text(_track.title), findsOneWidget);
    // A phone's card keeps its menu for a long press.
    await tester.longPress(find.text(_track.title));
    await tester.pumpAndSettle();
    expect(find.text('去 B 站搜这首'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('去 B 站搜这首'), findsNothing);
    // Members who have left wait behind 更多成员.
    expect(find.text('嘉然'), findsOneWidget);
    expect(find.text('向晚'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('收藏'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MusicPage)),
    );
    unawaited(
      Navigator.of(tester.element(find.byType(MusicPage))).push(
        MaterialPageRoute<void>(builder: (_) => const MusicFavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('播放全部'), findsOneWidget);
    expect(find.text(_track.title), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(await container.read(musicFavoriteIdsProvider.future), {_track.id});
    await tester.pumpWidget(_app(const MusicPlayerPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining(_track.singers), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('players fit a phone, the rail and a wide window at 2x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (width, player) in [
      (360.0, const MusicMiniPlayer() as Widget),
      (360.0, const MusicDockPlayer()),
      (816.0, const MusicPlayerBar()),
    ]) {
      tester.view.physicalSize = Size(width, 600);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(alignment: Alignment.bottomLeft, child: player),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_track.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
