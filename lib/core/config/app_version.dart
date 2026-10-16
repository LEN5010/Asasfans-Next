import 'dart:io' show Platform;

/// This build's version, as pubspec.yaml writes it without the build
/// number. A test keeps the two equal; the update check compares release
/// tags against it.
const appVersion = '3.1.0';

/// Sent to the app's own API and the video index, so their logs can tell
/// app traffic, its versions and platforms apart. dynamic_asoul's traffic
/// analysis matches this exact shape.
final appUserAgent = 'AsasfansNext/$appVersion (${Platform.operatingSystem})';
