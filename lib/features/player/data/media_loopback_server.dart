import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../../core/bilibili/bili_media_transport.dart';
import '../../../core/network/api_failure.dart';
import '../domain/playback_source.dart';

/// Serves acquired media to a local player over loopback.
///
/// A native player cannot be handed a signed upstream URL: the signature would
/// leak into player logs and platform caches, and the upstream needs per-hop
/// Referer and Cookie handling that a player will not perform. The player talks
/// only to `127.0.0.1`, and this relay re-issues each request through
/// [BiliMediaTransport], which owns the credential rules.
///
/// The listener binds to the loopback interface only, so nothing outside this
/// device can reach it. Each registered resource gets an unguessable path, and
/// a request for an unknown path is refused rather than proxied — the relay is
/// never a general-purpose proxy.
class MediaLoopbackServer {
  MediaLoopbackServer(this._transport);
  final BiliMediaTransport _transport;

  HttpServer? _server;
  final _resources = <String, _RelayTarget>{};
  final _random = Random.secure();
  bool _closed = false;

  /// Null until [start] has bound a port.
  Uri? get base {
    final server = _server;
    return server == null
        ? null
        : Uri(scheme: 'http', host: '127.0.0.1', port: server.port);
  }

  Future<void> start() async {
    if (_closed) throw const ApiFailure(ApiFailureKind.cancelled);
    if (_server != null) return;
    // InternetAddress.loopbackIPv4 keeps this off every external interface.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.autoCompress = false;
    _server = server;
    unawaited(_serve(server));
  }

  /// Publishes one track and returns the local URL for the manifest.
  ///
  /// The path is random so another local process cannot guess it and pull the
  /// stream; it is not a security boundary on its own, which is why the bind is
  /// loopback-only as well.
  Uri register(MediaResource resource, {required String bvid}) {
    final server = _server;
    if (server == null || _closed) {
      throw const ApiFailure(ApiFailureKind.unavailable);
    }
    final id = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '/media/$id';
    _resources[path] = _RelayTarget(resource: resource, bvid: bvid);
    return base!.replace(path: path);
  }

  /// Drops every published path. Call this when switching part or quality so a
  /// late player request cannot keep pulling the previous track.
  void clear() => _resources.clear();

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _resources.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      // Errors are handled per request: one bad request must not tear down the
      // listener and end playback of every other track.
      unawaited(
        _handle(request).catchError((Object _) async {
          try {
            await request.response.close();
          } catch (_) {}
        }),
      );
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final target = _resources[request.uri.path];
    // Only the exact registered path, and only the methods a player needs.
    if (target == null ||
        (request.method != 'GET' && request.method != 'HEAD')) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final head = request.method == 'HEAD';
    BiliMediaBody? body;
    try {
      body = await _open(target, request, head: head);
      response.statusCode = body.status;
      response.headers.set(HttpHeaders.contentTypeHeader, body.contentType);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      final length = body.contentLength;
      if (length != null) {
        response.headers.set(HttpHeaders.contentLengthHeader, '$length');
      }
      final range = body.contentRange;
      if (range != null) {
        response.headers.set(HttpHeaders.contentRangeHeader, range);
      }
      if (head) {
        await response.close();
        return;
      }
      // addStream propagates backpressure to the upstream body, so a paused
      // player stops the upstream read instead of buffering the whole track.
      await response.addStream(body.bytes);
      await response.close();
    } on ApiFailure catch (error) {
      // Headers may already be committed mid-stream; closing is then the only
      // honest signal, and the player retries or reports the failure.
      try {
        response.statusCode = switch (error.kind) {
          ApiFailureKind.invalidRequest => HttpStatus.badRequest,
          ApiFailureKind.cancelled => HttpStatus.serviceUnavailable,
          _ => HttpStatus.badGateway,
        };
      } catch (_) {}
      await response.close();
    } finally {
      await body?.close();
    }
  }

  /// Tries each mirror in turn. A source publishes backup hosts precisely
  /// because one can fail, so a dead mirror ends playback only when every
  /// location has been tried.
  ///
  /// Cancellation is not a mirror problem and stops immediately.
  Future<BiliMediaBody> _open(
    _RelayTarget target,
    HttpRequest request, {
    required bool head,
  }) async {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ApiFailure? last;
    for (final location in target.resource.locations) {
      try {
        return await _transport.open(
          location,
          bvid: target.bvid,
          range: range,
          head: head,
        );
      } on ApiFailure catch (error) {
        if (error.kind == ApiFailureKind.cancelled) rethrow;
        last = error;
      }
    }
    throw last ?? const ApiFailure(ApiFailureKind.unavailable);
  }
}

class _RelayTarget {
  const _RelayTarget({required this.resource, required this.bvid});
  final MediaResource resource;
  final String bvid;
}
