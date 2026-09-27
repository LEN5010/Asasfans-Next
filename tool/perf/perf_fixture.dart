import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';

/// A long, mixed 二创 feed for the Profile run: the same types, words and
/// image sizes on every run, so two builds see the same work. Images are
/// served offline from a handful of generated PNGs; every tile still asks
/// for its own URL, so each one is fetched and decoded on its own, as on
/// the real feed.
const perfFixtureRevision = 'perf-fixture-1';

/// Source pixel sizes. `long` is the plan's 1000 x 30000 strip.
const perfImages = <String, (int, int)>{
  'video': (1280, 720),
  'portrait': (900, 1200),
  'landscape': (1600, 900),
  'square': (1080, 1080),
  'long': (1000, 30000),
  'avatar': (160, 160),
};

Uri perfArt(String base, int n) =>
    Uri.https('fixture.invalid', '/perf/$base/$n.png');

const _pageSize = 24;
const _pages = 16;

/// The same order on every run: video, portrait, text, landscape, long
/// strip, multi-image, then the cycle turns with different words.
FanartItem perfItem(int n) {
  final kind = n % 6;
  final words = [
    '周六晚间杂谈的手书，第 $n 号',
    '贝拉练舞后的休息时间 · $n',
    '一篇很短的小故事：那天晚上，直播间的弹幕像雨一样落下来，她说今天也要好好吃饭哦。我把这句话抄在了便签上，贴在显示器的边框，一直贴到了现在。（$n）',
    '秋天的第一杯奶茶，给然然画了新衣服。枫叶和围巾的颜色调了很久 $n',
    '乃琳的长图条漫：从早到晚的一天（完整版请点开看）$n',
    '九宫格表情包合集，欢迎取用 $n',
  ][kind];
  final images = switch (kind) {
    0 => [perfArt('video', n)],
    1 => [perfArt('portrait', n)],
    2 => const <Uri>[],
    3 => [perfArt('landscape', n)],
    4 => [perfArt('long', n)],
    _ => [
      perfArt('square', n),
      perfArt('portrait', n + 1000),
      perfArt('landscape', n + 2000),
    ],
  };
  return FanartItem(
    identity: ContentIdentity(
      source: ContentSource.bilibiliDynamic,
      value: '7700${n.toString().padLeft(4, '0')}',
    ),
    text: words,
    authorName: ['小枝的调色盘', '拉姐的舞鞋', '晚安故事会', '条漫练习生'][n % 4],
    authorUid: '${100000 + n}',
    images: images,
    kind: FanartKind.fanart,
    contentType: switch (kind) {
      0 => FanartContentType.video,
      2 => FanartContentType.text,
      _ => FanartContentType.image,
    },
    category: kind == 0 ? FanartCategory.handwriting : FanartCategory.normal,
    characterTags: [
      [FanartCharacter.diana],
      [FanartCharacter.bella],
      [FanartCharacter.diana, FanartCharacter.eileen],
      [FanartCharacter.eileen],
    ][n % 4],
    authorAvatarUrl: perfArt('avatar', n % 8),
    sourceUrl: Uri.https('t.bilibili.com', '/7700$n'),
  );
}

class PerfFanart implements FanartRepository {
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    final index = cursor == null ? 0 : int.parse(cursor);
    final size = math.min(query.limit, _pageSize);
    // A little latency, as a real page has; the same on every run.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return FanartPage(
      items: [for (var i = 0; i < size; i++) perfItem(index * _pageSize + i)],
      snapshotId: perfFixtureRevision,
      nextCursor: index + 1 < _pages ? '${index + 1}' : null,
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => perfItem(0);
}

/// PNG bytes per base name, generated once before the run starts.
Future<Map<String, Uint8List>> generatePerfImages() async {
  final out = <String, Uint8List>{};
  for (final MapEntry(key: name, value: (width, height))
      in perfImages.entries) {
    out[name] = _png(width, height, name.hashCode);
  }
  return out;
}

/// Serves `fixture.invalid/perf/<base>/<n>.png` from [images]; nothing else
/// resolves, so the run never reaches a real server.
class PerfHttpOverrides extends HttpOverrides {
  PerfHttpOverrides(this.images);
  final Map<String, Uint8List> images;
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(images);
}

class _Client implements HttpClient {
  _Client(this.images);
  final Map<String, Uint8List> images;
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(_bytes(url));

  /// `perf/<base>/<n>.png` for the feed; `art/<name>.png` for the visual
  /// fixture that the other channels and Today reuse.
  Uint8List? _bytes(Uri url) {
    if (url.host != 'fixture.invalid') return null;
    final path = url.pathSegments;
    if (path.length == 3 && path[0] == 'perf') return images[path[1]];
    if (path.length != 2 || path[0] != 'art') return null;
    final name = path[1];
    return images[switch (name) {
      _ when name.startsWith('cover') => 'video',
      _ when name.startsWith('avatar') => 'avatar',
      _ when name.startsWith('land') || name.startsWith('wide') => 'landscape',
      _ when name.startsWith('square') => 'square',
      _ => 'portrait',
    }];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Network is disabled in the perf run.');
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List? bytes;
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List? bytes;
  @override
  int get statusCode => bytes == null ? HttpStatus.notFound : HttpStatus.ok;
  @override
  int get contentLength => bytes?.length ?? 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([
    ?bytes,
  ]).listen(onData, onError: onError, onDone: onDone, cancelOnError: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An RGB PNG with bands and diagonals, deflated row by row so a long
/// strip never sits in memory raw. The Sub filter keeps the files near the
/// size of the JPEGs a feed really serves, which matters: the bytes are
/// copied on the UI isolate before they are decoded.
Uint8List _png(int width, int height, int seed) {
  final compressed = BytesBuilder(copy: false);
  final sink = ZLibEncoder(
    level: 6,
  ).startChunkedConversion(ByteConversionSink.withCallback(compressed.add));
  final row = Uint8List(width * 3 + 1)..[0] = 1; // filter: Sub
  final hue = seed & 0xff;
  for (var y = 0; y < height; y++) {
    final band = (y ~/ 97) % 5;
    var r = 0, g = 0, b = 0;
    for (var x = 0; x < width; x++) {
      final nr = (hue + x * 255 ~/ width + band * 30) & 0xff;
      final ng = (y * 255 ~/ height + ((x + y) >> 3) % 32) & 0xff;
      final nb = (200 - band * 25 + ((x * 7 + y * 3) >> 4) % 16) & 0xff;
      final i = 1 + x * 3;
      row[i] = (nr - r) & 0xff;
      row[i + 1] = (ng - g) & 0xff;
      row[i + 2] = (nb - b) & 0xff;
      r = nr;
      g = ng;
      b = nb;
    }
    sink.add(Uint8List.fromList(row));
  }
  sink.close();
  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  void chunk(String type, List<int> data) {
    final typed = [...type.codeUnits, ...data];
    out
      ..add(_u32(data.length))
      ..add(typed)
      ..add(_u32(_crc(typed)));
  }

  chunk('IHDR', [..._u32(width), ..._u32(height), 8, 2, 0, 0, 0]);
  chunk('IDAT', compressed.takeBytes());
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [
  v >> 24 & 0xff,
  v >> 16 & 0xff,
  v >> 8 & 0xff,
  v & 0xff,
];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return c ^ 0xffffffff;
}
