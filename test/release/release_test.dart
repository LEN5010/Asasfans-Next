import 'dart:io';

import 'package:asasfans_next/core/config/app_version.dart';
import 'package:asasfans_next/features/release/data/github_release_source.dart';
import 'package:asasfans_next/features/release/domain/app_release.dart';
import 'package:asasfans_next/features/release/presentation/release_check.dart';
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
    final releases = GithubReleaseSource.decode([
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
        GithubReleaseSource.decode([_json('v3.0.0')]),
        _v('3.0.0-beta.2'),
      )?.version.label,
      '3.0.0',
    );
  });

  test('release notes lose their Markdown marks', () {
    final release = GithubReleaseSource.decode([_json('v3.0.0')]).single;
    expect(plainNotes(release.notes), '更新\n\n• 新功能');
  });
}
