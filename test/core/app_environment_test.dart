import 'package:asasfans_next/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relative routes retain the deployed /dynamics/api prefix', () {
    final env = AppEnvironment.fromDefines();
    expect(
      env.dynamicApiBaseUrl.resolve('fanart').toString(),
      'https://len5010.top/dynamics/api/fanart',
    );
  });

  test('rejects insecure and ambiguous API roots', () {
    for (final url in [
      'http://example.test/api/',
      'https://example.test/api',
      'https://secret@example.test/api/',
      'https://example.test/api/?token=x',
    ]) {
      expect(
        () => AppEnvironment(
          dynamicApiBaseUrl: Uri.parse(url),
          calendarUrl: Uri.parse('https://example.test/calendar.ics'),
        ),
        throwsArgumentError,
      );
    }
  });
}
