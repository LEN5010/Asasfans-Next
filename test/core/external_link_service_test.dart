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

    expect(
      app('https://live.bilibili.com/22637261'),
      Uri.parse('bilibili://live/22637261'),
    );
    expect(
      app(
        'https://search.bilibili.com/all?keyword=%E5%98%89%E7%84%B6%202026.6',
      ),
      Uri.parse('bilibili://search?keyword=%E5%98%89%E7%84%B6%202026.6'),
    );
    // The archive's dynamics link to /opus/, often with sharing parameters.
    for (final dynamic in [
      'https://www.bilibili.com/opus/1000000000000000001',
      'https://m.bilibili.com/opus/1000000000000000001/?spm_id_from=333.999',
      'https://m.bilibili.com/dynamic/1000000000000000001',
      'https://t.bilibili.com/1000000000000000001?share_source=copy',
    ]) {
      expect(
        app(dynamic),
        Uri.parse('bilibili://following/detail/1000000000000000001'),
        reason: dynamic,
      );
    }
    expect(
      app('https://www.bilibili.com/video/BV1xx411c7mD/?spm_id_from=333.1'),
      Uri.parse('bilibili://video/BV1xx411c7mD'),
    );
    expect(
      app('https://www.bilibili.com/video/av170001'),
      Uri.parse('bilibili://video/170001'),
    );
    expect(
      app('https://live.bilibili.com/22637261?from=search'),
      Uri.parse('bilibili://live/22637261'),
    );
    expect(
      app('https://live.bilibili.com/h5/22637261'),
      Uri.parse('bilibili://live/22637261'),
    );
    expect(
      app('https://space.bilibili.com/107261543/dynamic'),
      Uri.parse('bilibili://space/107261543'),
    );
    expect(app('https://search.bilibili.com/all?keyword=a&duration=4'), isNull);

    // Anything else keeps its web link, which Android then offers to the
    // Bilibili app by package when it is one of Bilibili's own.
    expect(app('https://www.bilibili.com/video/BV1xx411c7mD?p=2'), isNull);
    expect(app('https://www.bilibili.com/video/BV1xx411c7mD?t=30'), isNull);
    expect(app('https://www.bilibili.com/read/cv123'), isNull);
    expect(app('https://www.bilibili.com/opus/abc'), isNull);
    expect(app('https://t.bilibili.com/0123'), isNull);
    expect(app('https://www.bilibili.com/bangumi/play/ep1'), isNull);
    expect(app('https://evil.example/video/BV1xx411c7mD'), isNull);
    expect(app('https://evil.example/opus/1000000000000000001'), isNull);
    expect(app('http://www.bilibili.com/video/BV1xx411c7mD'), isNull);
    expect(app('https://www.douban.com/group/topic/1/'), isNull);

    expect(
      isBilibiliWeb(Uri.parse('https://www.bilibili.com/read/cv1')),
      isTrue,
    );
    expect(isBilibiliWeb(Uri.parse('https://b23.tv/abc')), isTrue);
    expect(
      isBilibiliWeb(Uri.parse('https://bilibili.com.evil.example/')),
      isFalse,
    );
    expect(isBilibiliWeb(Uri.parse('https://evilbilibili.com/')), isFalse);
    expect(isBilibiliWeb(Uri.parse('http://www.bilibili.com/')), isFalse);
  });
}
