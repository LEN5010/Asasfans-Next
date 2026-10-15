import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asasfans_next/core/config/app_version.dart';
import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:asasfans_next/features/release/data/release_source.dart';
import 'package:asasfans_next/features/release/domain/app_release.dart';
import 'package:asasfans_next/features/release/presentation/release_check.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

AppVersion _v(String text) => AppVersion.tryParse(text)!;

Map<String, Object?> _json(
  String tag, {
  bool draft = false,
  bool prerelease = false,
}) => {
  'tag_name': tag,
  'name': 'Asasfans Next $tag',
  'html_url': 'https://github.com/LEN5010/Asasfans-Next/releases/tag/$tag',
  'body': '## 更新\r\n\r\n- **新**功能',
  'draft': draft,
  'prerelease': prerelease,
  'published_at': '2026-10-20T08:00:00Z',
};

/// Answers every request with [status] and [body], recording the URLs.
class _Server implements HttpClientAdapter {
  _Server(this.status, this.body);
  final int status;
  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the app version is pubspec version without the build number', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)![1]!;
    expect(version.split('+').first, appVersion);
    expect(AppVersion.tryParse(appVersion), isNotNull);
  });

  test('the user agent has the shape dynamic_asoul counts as the app', () {
    expect(
      appUserAgent,
      matches(
        RegExp(r'^AsasfansNext/\d+\.\d+\.\d+(-[0-9A-Za-z.]+)? \([a-z]+\)$'),
      ),
    );
  });

  test(
    'releases come from dynamic_asoul, and from GitHub when it fails',
    () async {
      ReleaseSource source(_Server api, _Server github) => ReleaseSource(
        PublicApiClient(
          Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
            ..httpClientAdapter = api,
        ),
        Dio()..httpClientAdapter = github,
      );
      final feed = _Server(200, {
        'releases': [
          {
            'version': '3.0.0-beta.2',
            'title': 'Asasfans Next v3.0.0-beta.2',
            'page':
                'https://github.com/LEN5010/Asasfans-Next/releases/tag/v3.0.0-beta.2',
            'notes': 'notes',
            'prerelease': true,
            'publishedAt': '2026-10-20T08:00:00Z',
          },
        ],
        'checkedAt': '2026-10-20T08:01:00Z',
      });
      final github = _Server(200, [_json('v3.0.0')]);
      final fromApi = await source(feed, github).releases();
      expect(fromApi.single.version.label, '3.0.0-beta.2');
      expect(fromApi.single.preRelease, isTrue);
      expect(feed.requests.single.uri.path, '/api/app/release');
      expect(github.requests, isEmpty);

      final down = _Server(503, {'code': 'APP_RELEASE_UNAVAILABLE'});
      final fromGithub = await source(down, github).releases();
      expect(fromGithub.single.version.label, '3.0.0');
      expect(github.requests.single.uri, ReleaseSource.githubUrl);
    },
  );

  test('versions order as semantic versions', () {
    final ordered = [
      '2.0.0',
      '3.0.0-alpha',
      '3.0.0-beta.1',
      '3.0.0-beta.2',
      '3.0.0-beta.10',
      '3.0.0-rc.1',
      '3.0.0',
      '3.0.1',
      '3.1.0',
    ].map(_v).toList();
    for (var i = 1; i < ordered.length; i++) {
      expect(ordered[i - 1].compareTo(ordered[i]), lessThan(0));
    }
    expect(_v('v3.0.0-beta.1+202'), _v('3.0.0-beta.1'));
    expect(_v('v3.0.0+5').label, '3.0.0');
    expect(AppVersion.tryParse('latest'), isNull);
  });

  test('a pre-release build is offered pre-releases, a stable one is not', () {
    final releases = ReleaseSource.decodeGithub([
      _json('v2.0.0'),
      _json('v3.0.0-beta.2', prerelease: true),
      _json('v3.0.0-beta.3', draft: true),
      _json('nightly'),
    ]);
    expect(releases.map((r) => r.version.label), ['2.0.0', '3.0.0-beta.2']);
    expect(
      newerRelease(releases, _v('3.0.0-beta.1'))?.version.label,
      '3.0.0-beta.2',
    );
    expect(newerRelease(releases, _v('3.0.0-beta.2')), isNull);
    expect(newerRelease(releases, _v('2.0.0')), isNull);
    expect(
      newerRelease(
        ReleaseSource.decodeGithub([_json('v3.0.0')]),
        _v('3.0.0-beta.2'),
      )?.version.label,
      '3.0.0',
    );
  });

  test('release notes lose their Markdown marks', () {
    final release = ReleaseSource.decodeGithub([_json('v3.0.0')]).single;
    expect(plainNotes(release.notes), '更新\n\n• 新功能');
  });
}
