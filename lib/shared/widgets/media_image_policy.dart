import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'media_cover.dart';

/// Request and decode sizes for network images, from the space they are drawn
/// in rather than a fixed guess.
///
/// Two things are kept apart:
/// - the *preview* URI (a CDN transform, see [displayImageUri]) is only ever
///   used for display; the model keeps the original;
/// - the *decode* size bounds memory whatever the server returns — a CDN
///   transform does nothing for other hosts, which send the original.
///
/// Sizes snap to a few buckets so near-identical layouts share one cache
/// entry instead of each decoding its own copy.
abstract final class MediaImagePolicy {
  static const buckets = [
    64,
    96,
    128,
    192,
    256,
    384,
    512,
    640,
    800,
    1080,
    1440,
    2048,
  ];

  /// Used when the layout width is unknown (unbounded or zero).
  static const unknownWidth = 640;

  /// The largest decode edge for a full-screen image: beyond this, device
  /// memory rather than screen resolution is the limit.
  static const maxEdge = 2560;

  /// Decoded pixels allowed for one image (about 64 MB as RGBA). A very long
  /// image is decoded narrower instead of into a texture most GPUs refuse.
  static const maxPixels = 16 * 1024 * 1024;

  /// Smallest bucket that covers [logicalWidth] at [devicePixelRatio].
  static int decodeWidth(double logicalWidth, double devicePixelRatio) {
    if (!logicalWidth.isFinite || logicalWidth <= 0) return unknownWidth;
    final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    final pixels = (logicalWidth * ratio).ceil();
    return buckets.firstWhere(
      (bucket) => bucket >= pixels,
      orElse: () => buckets.last,
    );
  }

  /// A thumbnail or card image: a CDN preview at the bucket width, decoded
  /// no larger than that bucket.
  ///
  /// A box drawn with [BoxFit.cover] passes its [logicalHeight] too. The
  /// image is then decoded to cover the whole box, once its own size is
  /// known, instead of to the box width: a landscape picture in a portrait
  /// box would otherwise be decoded narrow and stretched up, blurred. The
  /// CDN copy is asked for at the box's longer side, which covers squares and
  /// portraits exactly and wide art most of the way, without guessing a
  /// ratio the list does not know.
  static ImageProvider preview(
    Uri uri, {
    required double logicalWidth,
    required double devicePixelRatio,
    double? logicalHeight,
  }) {
    final width = decodeWidth(logicalWidth, devicePixelRatio);
    if (logicalHeight != null &&
        logicalHeight.isFinite &&
        logicalHeight > 0 &&
        logicalWidth.isFinite &&
        logicalWidth > 0) {
      final height = decodeWidth(logicalHeight, devicePixelRatio);
      return CoverDecodeImage(
        NetworkImage(
          displayImageUri(uri, width: math.max(width, height)).toString(),
        ),
        // Buckets on both sides, so near-identical boxes share one entry.
        width: width,
        height: height,
      );
    }
    return ResizeImage(
      NetworkImage(displayImageUri(uri, width: width).toString()),
      width: width,
      policy: ResizeImagePolicy.fit,
      height: maxPixels ~/ width,
    );
  }

  /// The original image for full viewing: its own URI, decoded to the
  /// viewport width (never below [unknownWidth], never above [maxEdge]) and
  /// within [maxPixels]. Aspect ratio is always kept.
  static ImageProvider original(
    Uri uri, {
    required double viewportWidth,
    required double devicePixelRatio,
  }) {
    final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    final width = viewportWidth.isFinite && viewportWidth > 0
        ? math.min(
            maxEdge,
            math.max(unknownWidth, (viewportWidth * ratio).ceil()),
          )
        : unknownWidth;
    return ResizeImage(
      NetworkImage(uri.toString()),
      width: width,
      height: maxPixels ~/ width,
      policy: ResizeImagePolicy.fit,
    );
  }
}

/// Decodes an image just large enough to cover a [width] x [height] pixel
/// box, keeping its ratio: never larger than the source, and never over
/// [MediaImagePolicy.maxPixels].
@immutable
class CoverDecodeImage extends ImageProvider<CoverDecodeKey> {
  const CoverDecodeImage(
    this.imageProvider, {
    required this.width,
    required this.height,
  });
  final ImageProvider imageProvider;
  final int width;
  final int height;

  /// The decoded size for a source of [sourceWidth] x [sourceHeight].
  static ({int width, int height}) targetSize(
    int sourceWidth,
    int sourceHeight,
    int boxWidth,
    int boxHeight,
  ) {
    var scale = math.min(
      1.0,
      math.max(boxWidth / sourceWidth, boxHeight / sourceHeight),
    );
    final pixels = sourceWidth * sourceHeight * scale * scale;
    if (pixels > MediaImagePolicy.maxPixels) {
      // Rounded down, so the budget holds exactly.
      scale *= math.sqrt(MediaImagePolicy.maxPixels / pixels);
      return (
        width: math.max(1, (sourceWidth * scale).floor()),
        height: math.max(1, (sourceHeight * scale).floor()),
      );
    }
    return (
      width: math.max(1, (sourceWidth * scale).round()),
      height: math.max(1, (sourceHeight * scale).round()),
    );
  }

  @override
  Future<CoverDecodeKey> obtainKey(ImageConfiguration configuration) =>
      imageProvider
          .obtainKey(configuration)
          .then((key) => CoverDecodeKey(key, width, height));

  @override
  ImageStreamCompleter loadImage(
    CoverDecodeKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeCovering(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) => decode(
      buffer,
      getTargetSize: (sourceWidth, sourceHeight) {
        final size = targetSize(sourceWidth, sourceHeight, width, height);
        return ui.TargetImageSize(width: size.width, height: size.height);
      },
    );
    return imageProvider.loadImage(key.source, decodeCovering);
  }
}

@immutable
class CoverDecodeKey {
  const CoverDecodeKey(this.source, this.width, this.height);
  final Object source;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is CoverDecodeKey &&
      other.source == source &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(source, width, height);
}
