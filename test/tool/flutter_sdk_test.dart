import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/flutter_sdk.dart';

void main() {
  late Directory sdk;
  final revision = List.filled(40, 'a').join();
  final pin = <String, Object?>{
    'version': '3.47.3',
    'revision': revision,
    'dartVersion': '3.13.3',
    'channel': 'stable',
  };
  ProcessResult cleanGit(List<String> args) =>
      ProcessResult(1, 0, args.first == 'rev-parse' ? '$revision\n' : '', '');
  setUp(() {
    sdk = Directory.systemTemp.createTempSync('asasfans-sdk-check-');
    Directory('${sdk.path}/.git').createSync();
    Directory('${sdk.path}/bin/cache/dart-sdk').createSync(recursive: true);
    File('${sdk.path}/bin/cache/flutter.version.json').writeAsStringSync(
      jsonEncode({
        'frameworkVersion': pin['version'],
        'frameworkRevision': revision,
        'channel': 'stable',
        'dartSdkVersion': pin['dartVersion'],
      }),
    );
    File(
      '${sdk.path}/bin/cache/dart-sdk/version',
    ).writeAsStringSync('3.13.3\n');
  });
  tearDown(() => sdk.deleteSync(recursive: true));

  test('accepts a matching clean SDK without downloading or launching it', () {
    verifyFlutterSdk(sdk, pin, gitProbe: cleanGit);
  });
  test('does not accept a directory merely named after the pinned version', () {
    expect(
      () => verifyFlutterSdk(
        sdk,
        pin,
        gitProbe: (_) => ProcessResult(1, 0, 'wrong', ''),
      ),
      throwsFormatException,
    );
  });
  test('rejects modified SDK sources', () {
    expect(
      () => verifyFlutterSdk(
        sdk,
        pin,
        gitProbe: (args) =>
            args.first == 'diff' ? ProcessResult(1, 1, '', '') : cleanGit(args),
      ),
      throwsFormatException,
    );
  });
  test('rejects a mismatched cached Dart', () {
    File('${sdk.path}/bin/cache/dart-sdk/version').writeAsStringSync('3.9.2');
    expect(
      () => verifyFlutterSdk(sdk, pin, gitProbe: cleanGit),
      throwsFormatException,
    );
  });
  test('rejects a cached framework version from another checkout', () {
    final file = File('${sdk.path}/bin/cache/flutter.version.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    data['frameworkVersion'] = '3.35.4';
    file.writeAsStringSync(jsonEncode(data));
    expect(
      () => verifyFlutterSdk(sdk, pin, gitProbe: cleanGit),
      throwsFormatException,
    );
  });
  test('does not let git discover the enclosing app repository', () {
    Directory('${sdk.path}/.git').deleteSync();
    expect(
      () => verifyFlutterSdk(sdk, pin, gitProbe: cleanGit),
      throwsFormatException,
    );
  });
  test('rejects a floating version pin', () {
    expect(
      () => verifyFlutterSdk(sdk, {
        ...pin,
        'version': 'stable',
      }, gitProbe: cleanGit),
      throwsFormatException,
    );
  });
  test('manifest, editor hint, pubspec and both CI SDK pins agree', () {
    final actual =
        jsonDecode(File('tool/flutter-sdk.json').readAsStringSync())
            as Map<String, dynamic>;
    final version = actual['version'] as String;
    expect(File('.flutter-version').readAsStringSync().trim(), version);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('flutter: ">=$version"'),
    );
    final workflow = File(
      '.github/workflows/flutter-checks.yml',
    ).readAsStringSync();
    expect(
      RegExp("flutter-version: '$version'").allMatches(workflow),
      hasLength(1),
    );
    final developmentWorkflow = File(
      '.github/workflows/flutter-development-validation.yml',
    ).readAsStringSync();
    expect(developmentWorkflow, contains("flutter-version: '$version'"));
    expect(developmentWorkflow, isNot(contains('secrets.')));
    expect(developmentWorkflow, isNot(contains('--release')));
    expect(developmentWorkflow, contains('build ios --debug --no-codesign'));
  });
}
