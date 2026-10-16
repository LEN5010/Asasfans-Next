import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bilibili pages the app builds go to the Bilibili app first', () {
    Uri? app(String web) => bilibiliAppLink(Uri.parse(web));

    expect(
      app('https://www.bilibili.com/video/BV1xx411c7mD'),
      Uri.parse('bilibili://video/BV1xx411c7mD'),
    );
    expect(
      app('https://t.bilibili.com/1000000000000000001'),
      Uri.parse('bilibili://following/detail/1000000000000000001'),
    );
    expect(
      app('https://space.bilibili.com/107261543'),
      Uri.parse('bilibili://space/107261543'),
    );

    // Anything else keeps its web link.
    expect(app('https://www.bilibili.com/video/BV1xx411c7mD?p=2'), isNull);
    expect(app('https://www.bilibili.com/video/av170001'), isNull);
    expect(app('https://www.bilibili.com/bangumi/play/ep1'), isNull);
    expect(app('https://evil.example/video/BV1xx411c7mD'), isNull);
    expect(app('http://www.bilibili.com/video/BV1xx411c7mD'), isNull);
    expect(app('https://www.douban.com/group/topic/1/'), isNull);
  });
}
