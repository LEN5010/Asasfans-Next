import 'package:asasfans_next/shared/widgets/media_image_policy.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  (String url, ResizeImage resize) unwrap(ImageProvider provider) {
    final resize = provider as ResizeImage;
    return ((resize.imageProvider as NetworkImage).url, resize);
  }

  test('decode width follows the drawn size, snapped to buckets', () {
    // A 180dp card at 3x needs 540 px: the next bucket, not a fixed 800.
    expect(MediaImagePolicy.decodeWidth(180, 3), 640);
    expect(MediaImagePolicy.decodeWidth(180, 1), 192);
    // Near-identical layouts share one cache entry.
    expect(
      MediaImagePolicy.decodeWidth(171, 2),
      MediaImagePolicy.decodeWidth(190, 2),
    );
    // Very wide layouts stop at the largest bucket.
    expect(MediaImagePolicy.decodeWidth(4000, 3), 2048);
  });

  test('unknown layout or ratio falls back to a safe middle', () {
    expect(MediaImagePolicy.decodeWidth(double.infinity, 2), 640);
    expect(MediaImagePolicy.decodeWidth(0, 2), 640);
    expect(MediaImagePolicy.decodeWidth(100, double.nan), 128);
  });

  test('preview uses the CDN transform only for Bilibili hosts', () {
    final (bili, resize) = unwrap(
      MediaImagePolicy.preview(
        Uri.parse('https://i0.hdslb.com/bfs/new_dyn/a.png'),
        logicalWidth: 180,
        devicePixelRatio: 3,
      ),
    );
    expect(bili, 'https://i0.hdslb.com/bfs/new_dyn/a.png@640w.webp');
    expect(resize.width, 640);
    expect(resize.policy, ResizeImagePolicy.fit);
    final (gif, _) = unwrap(
      MediaImagePolicy.preview(
        Uri.parse('https://i0.hdslb.com/bfs/emote/x.gif'),
        logicalWidth: 32,
        devicePixelRatio: 3,
      ),
    );
    // GIFs stay animated.
    expect(gif, endsWith('.gif@96w.gif'));
    final (foreign, foreignResize) = unwrap(
      MediaImagePolicy.preview(
        Uri.parse('https://img.example.org/big.jpg'),
        logicalWidth: 180,
        devicePixelRatio: 3,
      ),
    );
    // No transform is possible there, so only the decode bound protects memory.
    expect(foreign, 'https://img.example.org/big.jpg');
    expect(foreignResize.width, 640);
  });

  test('the original is never rewritten and stays inside a pixel budget', () {
    const source = 'https://i0.hdslb.com/bfs/new_dyn/long.png';
    final (url, resize) = unwrap(
      MediaImagePolicy.original(
        Uri.parse(source),
        viewportWidth: 400,
        devicePixelRatio: 3,
      ),
    );
    expect(url, source);
    expect(resize.width, 1200);
    expect(
      resize.width! * resize.height!,
      lessThanOrEqualTo(MediaImagePolicy.maxPixels),
    );
    expect(resize.policy, ResizeImagePolicy.fit);
    final (_, wide) = unwrap(
      MediaImagePolicy.original(
        Uri.parse(source),
        viewportWidth: 3000,
        devicePixelRatio: 2,
      ),
    );
    expect(wide.width, MediaImagePolicy.maxEdge);
    final (_, narrow) = unwrap(
      MediaImagePolicy.original(
        Uri.parse(source),
        viewportWidth: 100,
        devicePixelRatio: 1,
      ),
    );
    // Never below a readable floor, even in a tiny window.
    expect(narrow.width, MediaImagePolicy.unknownWidth);
  });

  test('a cover box decodes enough to fill its height, never more', () {
    // A 1600x900 landscape picture in a 175x219 portrait box at 3x
    // (bucketed 640x800): filling the height needs 1422 px of width, not
    // the 640 a width-only decode would give and then stretch.
    expect(CoverDecodeImage.targetSize(1600, 900, 640, 800), (
      width: 1422,
      height: 800,
    ));
    // A portrait picture is bound by the width as before.
    expect(CoverDecodeImage.targetSize(900, 1600, 640, 800), (
      width: 640,
      height: 1138,
    ));
    // Never above the source...
    expect(CoverDecodeImage.targetSize(300, 200, 640, 800), (
      width: 300,
      height: 200,
    ));
    // ...and never over the pixel budget, whatever the ratio.
    final strip = CoverDecodeImage.targetSize(2000, 60000, 2048, 2048);
    expect(
      strip.width * strip.height,
      lessThanOrEqualTo(MediaImagePolicy.maxPixels),
    );
  });

  test('a preview with a height asks the CDN for the longer side', () {
    final provider = MediaImagePolicy.preview(
      Uri.parse('https://i0.hdslb.com/bfs/new_dyn/a.png'),
      logicalWidth: 175,
      logicalHeight: 219,
      devicePixelRatio: 3,
    );
    expect(provider, isA<CoverDecodeImage>());
    final cover = provider as CoverDecodeImage;
    expect(
      (cover.imageProvider as NetworkImage).url,
      'https://i0.hdslb.com/bfs/new_dyn/a.png@800w.webp',
    );
    expect((cover.width, cover.height), (640, 800));
    // Two boxes in the same buckets share one cache key.
    expect(
      CoverDecodeKey('a', cover.width, cover.height),
      CoverDecodeKey('a', 640, 800),
    );
  });
}
