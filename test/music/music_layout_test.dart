import 'package:asasfans_next/features/music/application/music_audio_handler.dart';
import 'package:asasfans_next/features/music/application/music_providers.dart';
import 'package:asasfans_next/features/music/data/music_catalog_repository.dart';
import 'package:asasfans_next/features/music/data/music_stream_repository.dart';
import 'package:asasfans_next/features/music/domain/music_track.dart';
import 'package:asasfans_next/features/music/presentation/music_page.dart';
import 'package:asasfans_next/features/music/presentation/music_player_page.dart';
import 'package:asasfans_next/features/music/presentation/music_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  overrides: [
    musicCatalogProvider.overrideWith((ref) async => MusicCatalog([_track])),
    musicAudioHandlerProvider.overrideWith((ref) => _QueueFixture()),
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
  testWidgets('music page and multi-member player fit 360 wide at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const MusicPage()));
    await tester.pumpAndSettle();
    expect(find.text('搜索歌名'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(const MusicPlayerPage()));
    await tester.pumpAndSettle();
    expect(find.text(_track.singers), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar mini player fits 192 wide with 2x text', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SizedBox(width: 192, child: MusicMiniPlayer(compact: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_track.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
