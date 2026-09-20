import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same raw identifier on different sources is not one item', () {
    const dynamic = ContentIdentity(
      source: ContentSource.bilibiliDynamic,
      value: '123',
    );
    const topic = ContentIdentity(
      source: ContentSource.doubanTopic,
      value: '123',
    );
    expect(dynamic, isNot(topic));
    expect({dynamic, topic}, hasLength(2));
  });

  test('content identity has stable value equality', () {
    const first = ContentIdentity(
      source: ContentSource.bilibiliVideo,
      value: 'BV-test',
    );
    const second = ContentIdentity(
      source: ContentSource.bilibiliVideo,
      value: 'BV-test',
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
