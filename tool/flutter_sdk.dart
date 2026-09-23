import 'dart:convert';
import 'dart:io';

typedef SdkGitProbe = ProcessResult Function(List<String> arguments);

/// Shared by POSIX and PowerShell entry points. No pub packages are required.
/// The wrappers select either an explicit SDK or the installed PATH entry.
/// An invalid SDK is rejected, never replaced with another candidate.
void verifyFlutterSdk(
  Directory sdk,
  Map<String, Object?> pin, {
  SdkGitProbe? gitProbe,
}) {
  final version = pin['version'];
  final revision = pin['revision'];
  final dartVersion = pin['dartVersion'];
  if (version is! String ||
      !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
      revision is! String ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(revision) ||
      dartVersion is! String ||
      pin['channel'] != 'stable') {
    throw const FormatException('Invalid Flutter SDK pin.');
  }
  if (!Directory('${sdk.path}/.git').existsSync() &&
      !File('${sdk.path}/.git').existsSync()) {
    throw const FormatException(
      'SDK has no Git identity; reinstall the pinned archive.',
    );
  }
  final environment = Map<String, String>.of(Platform.environment)
    ..remove('GIT_DIR')
    ..remove('GIT_WORK_TREE')
    ..remove('GIT_INDEX_FILE')
    ..remove('GIT_COMMON_DIR');
  final probe =
      gitProbe ??
      (arguments) => Process.runSync(
        'git',
        ['-C', sdk.path, ...arguments],
        environment: environment,
        includeParentEnvironment: false,
      );
  final head = probe(['rev-parse', '--verify', 'HEAD']);
  if (head.exitCode != 0 || (head.stdout as String).trim() != revision) {
    throw FormatException('Expected Flutter $version at revision $revision.');
  }
  final dirty = probe(['diff', '--quiet', 'HEAD', '--', 'bin', 'packages']);
  if (dirty.exitCode != 0) {
    throw const FormatException(
      'SDK sources are modified or unreadable; use a clean pinned SDK.',
    );
  }
  final actual =
      jsonDecode(
            File(
              '${sdk.path}/bin/cache/flutter.version.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final actualDart = File(
    '${sdk.path}/bin/cache/dart-sdk/version',
  ).readAsStringSync().trim();
  if (actual['frameworkVersion'] != version ||
      actual['frameworkRevision'] != revision ||
      actual['channel'] != pin['channel'] ||
      actual['dartSdkVersion'] != dartVersion ||
      actualDart != dartVersion) {
    throw FormatException(
      'SDK cache does not match Flutter $version / Dart $dartVersion.',
    );
  }
}

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length < 2) {
      throw const FormatException('Use tool/flutterw or tool/flutterw.ps1.');
    }
    final root = Directory(arguments[0]).absolute;
    final sdk = Directory(arguments[1]).absolute;
    final pin =
        jsonDecode(
              File('${root.path}/tool/flutter-sdk.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    verifyFlutterSdk(sdk, pin);
    final forwarded = arguments.skip(2).toList();
    if (forwarded.length == 1 && forwarded.single == '--verify-sdk') {
      stdout.writeln(
        jsonEncode({
          'sdk': sdk.path,
          'version': pin['version'],
          'revision': pin['revision'],
          'dartVersion': pin['dartVersion'],
        }),
      );
      return;
    }
    final useDart = forwarded.isNotEmpty && forwarded.first == '--dart';
    if (useDart) forwarded.removeAt(0);
    final executable = useDart ? 'dart' : 'flutter';
    final suffix = Platform.isWindows ? '.bat' : '';
    final process = await Process.start(
      '${sdk.path}/bin/$executable$suffix',
      forwarded,
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on Object catch (error) {
    stderr.writeln('Pinned SDK check/launch failed: $error');
    exitCode = 78;
  }
}
