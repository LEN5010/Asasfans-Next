import 'dart:math' as math;

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
  static ImageProvider preview(
    Uri uri, {
    required double logicalWidth,
    required double devicePixelRatio,
  }) {
    final width = decodeWidth(logicalWidth, devicePixelRatio);
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
