import 'dart:convert';
import '../../../core/network/api_failure.dart';
import '../domain/playback_source.dart';

/// Generates only local stream references. The native player must never
/// receive a signed upstream URL or a general-purpose Cookie header.
abstract final class DashManifest {
  static String build(
    PlaybackSource source, {
    required int quality,
    required Uri Function(MediaResource) localResource,
  }) {
    final video = source.videoFor(quality);
    if (video == null) throw const ApiFailure(ApiFailureKind.invalidRequest);
    final audio = source.defaultAudio;
    final duration =
        'PT${(source.duration.inMilliseconds / 1000).toStringAsFixed(3)}S';
    String representation(DashTrack track) {
      final uri = localResource(track.resource);
      if (uri.scheme != 'http' ||
          uri.host != '127.0.0.1' ||
          uri.port < 1024 ||
          uri.port > 65535 ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          uri.path.length > 512 ||
          !RegExp(
            r'^/[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_-]+)*$',
          ).hasMatch(uri.path) ||
          uri.hasQuery) {
        throw const ApiFailure(ApiFailureKind.invalidRequest);
      }
      String xml(String value) =>
          const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
      return '<AdaptationSet contentType="${track.kind.name}" mimeType="${xml(track.mime)}" segmentAlignment="true">'
          '<Representation id="${track.id}-${track.codecId}" codecs="${xml(track.codec)}" bandwidth="${track.bandwidth}"'
          '${track.width == null ? '' : ' width="${track.width}" height="${track.height}"'}'
          '${track.frameRate == null ? '' : ' frameRate="${xml(track.frameRate!)}"'}>'
          '<BaseURL>${xml(uri.toString())}</BaseURL>'
          '<SegmentBase indexRange="${track.indexRange.wire}"><Initialization range="${track.initialization.wire}"/></SegmentBase>'
          '</Representation></AdaptationSet>';
    }

    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" '
        'mediaPresentationDuration="$duration" minBufferTime="PT1.5S"><Period duration="$duration">'
        '${representation(video)}${audio == null ? '' : representation(audio)}</Period></MPD>';
  }
}
