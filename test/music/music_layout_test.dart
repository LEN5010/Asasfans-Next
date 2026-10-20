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
import '../helpers/preferences_fixture.dart';
import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/app/theme/app_theme.dart';

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
  List<MusicTrack> played = [];
  @override
  Future<void> playTracks(List<MusicTrack> values, {int start = 0}) async {
    played = values;
  }

  @override
  MusicTrack get current => _track;
  @override
  List<MusicTrack> get tracks => [_track];
  @override
  int get index => 0;
}

Widget _app(Widget home, {List<MusicTrack>? tracks, double textScale = 2}) =>
    ProviderScope(
      // A fresh scope and navigator for each pumped app.
      key: UniqueKey(),
      overrides: [
        ...offlineLibrary(),
        offlinePreferences(),
        musicCatalogProvider.overrideWith(
          (ref) async => MusicCatalog(tracks ?? [_track]),
        ),
        musicAudioHandlerProvider.overrideWith((ref) => _QueueFixture()),
        memberAvatarsProvider.overrideWithValue(const {}),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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

  testWidgets(
    'short desktop player keeps controls visible and scales its cover',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var lastCoverSize = 0.0;
      for (final height in [560.0, 680.0, 820.0]) {
        tester.view.physicalSize = Size(1100, height);
        await tester.pumpWidget(_app(const MusicPlayerPage(), textScale: 1));
        await tester.pumpAndSettle();
        final cover = find.byType(MusicCover).first;
        final size = tester.getSize(cover).width;
        expect(size, greaterThan(lastCoverSize));
        lastCoverSize = size;
        expect(tester.getTopLeft(cover).dy, greaterThanOrEqualTo(56));
        expect(
          tester.getBottomRight(find.text('搜录播')).dy,
          lessThanOrEqualTo(height),
        );
        expect(
          tester.getSize(find.byType(MusicPlayButton)),
          const Size(48, 48),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('member choices intersect and more members stay opt-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MusicTrack song(String id, List<String> members) => MusicTrack(
      id: id,
      title: id,
      members: members,
      date: DateTime(2026, 10, 15),
      duration: const Duration(minutes: 3),
      status: 'Live',
    );
    await tester.pumpWidget(
      _app(
        const MusicPage(),
        tracks: [
          song('嘉然独唱', ['嘉然']),
          song('双人合唱', ['嘉然', '贝拉']),
          song('向晚独唱', ['向晚']),
          song('珈乐合唱', ['嘉然', '珈乐']),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('全部成员'), findsNothing);
    expect(find.text('嘉然独唱'), findsOneWidget);
    expect(find.text('向晚独唱'), findsNothing);
    expect(find.text('珈乐合唱'), findsNothing);
    await tester.tap(find.byTooltip('嘉然'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('贝拉'));
    await tester.pumpAndSettle();
    expect(find.text('双人合唱'), findsOneWidget);
    expect(find.text('嘉然独唱'), findsNothing);
    await tester.tap(find.byTooltip('嘉然'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('贝拉'));
    await tester.pumpAndSettle();
    final tile = find.ancestor(
      of: find.text('嘉然独唱'),
      matching: find.byType(MusicSongTile),
    );
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放这天'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MusicPage)),
    );
    final handler = container.read(musicAudioHandlerProvider) as _QueueFixture;
    expect(handler.played.map((song) => song.id), ['嘉然独唱', '双人合唱']);
    await tester.tap(find.text('更多成员'));
    await tester.pumpAndSettle();
    if (find.text('我已了解，继续').evaluate().isNotEmpty) {
      await tester.tap(find.text('我已了解，继续'));
      await tester.pumpAndSettle();
    }
    expect(find.text('向晚独唱'), findsOneWidget);
    expect(find.text('珈乐合唱'), findsOneWidget);
    expect(AppTheme.memberColors['向晚'], const Color(0xFF5B9BD5));
    expect(AppTheme.memberColors['珈乐'], const Color(0xFF9B72CF));
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.text('向晚独唱'), findsNothing);
  });

  testWidgets('player volume and hearts save through the personal library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const MusicPlayerPage()));
    await tester.pumpAndSettle();
    final volume = find.descendant(
      of: find.byType(MusicVolumeControl),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(volume);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(volume));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MusicPlayerPage)),
    );
    expect(
      container.read(preferencesControllerProvider).values.musicVolume,
      closeTo(.5, .05),
    );
    await tester.ensureVisible(find.byTooltip('收藏'));
    await tester.tap(find.byTooltip('收藏'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    expect(await container.read(musicFavoriteIdsProvider.future), {_track.id});
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
