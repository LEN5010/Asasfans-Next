class AppEnvironment {
  AppEnvironment({required this.dynamicApiBaseUrl, required this.calendarUrl}) {
    for (final uri in [dynamicApiBaseUrl, calendarUrl]) {
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw ArgumentError('Public sources require absolute HTTPS URLs.');
      }
    }
    if (!dynamicApiBaseUrl.path.endsWith('/')) {
      throw ArgumentError('API base URL must end with a slash.');
    }
  }

  factory AppEnvironment.fromDefines() => AppEnvironment(
    dynamicApiBaseUrl: Uri.parse(
      const String.fromEnvironment(
        'DYNAMIC_API_BASE_URL',
        defaultValue: 'https://len5010.top/dynamics/api/',
      ),
    ),
    calendarUrl: Uri.parse(
      const String.fromEnvironment(
        'CALENDAR_URL',
        defaultValue: 'https://asoul.love/calendar.ics',
      ),
    ),
  );

  final Uri dynamicApiBaseUrl;
  final Uri calendarUrl;
}
