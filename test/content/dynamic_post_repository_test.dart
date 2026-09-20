import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/data/dynamic_post_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Uri.parse('https://example.test/dynamics/api/');

  test('keeps snowflake ids as strings and never as numbers', () {
    final posts = DynamicPostRepository.decodeOnThisDay({
      'items': [
        {
          'dynamicId': '559393488581344426',
          'member': {'id': 'uid:703007996', 'name': '嘉然今天吃什么'},
          'type': 'image',
          'contentText': '正文',
          'publishedAt': '2021-08-16T02:52:26.000Z',
          'url': 'https://t.bilibili.com/559393488581344426',
          'images': ['https://i0.hdslb.com/a.jpg'],
          'likeCount': 10,
          'commentCount': 2,
          'forwardCount': 1,
          'serverAddedField': 'ignored',
        },
      ],
    }, baseUrl: base);

    final post = posts.single;
    expect(post.identity.value, '559393488581344426');
    expect(post.identity.source, ContentSource.bilibiliDynamic);
    expect(post.member.name, '嘉然今天吃什么');
    expect(post.type, DynamicType.image);
    expect(post.publishedAt, DateTime.utc(2021, 8, 16, 2, 52, 26));
    expect(post.likeCount, 10);
  });

  test('a video dynamic stays a dynamic rather than becoming a video', () {
    final posts = DynamicPostRepository.decodeOnThisDay({
      'items': [
        {
          'dynamicId': '1',
          'type': 'video',
          'url': 'https://www.bilibili.com/video/BV1xx',
        },
      ],
    }, baseUrl: base);

    // Identity remains the dynamic id, not the referenced BVID.
    expect(posts.single.identity.value, '1');
    expect(posts.single.type, DynamicType.video);
  });

  test('a forward keeps the original author separate', () {
    final posts = DynamicPostRepository.decodeOnThisDay({
      'items': [
        {
          'dynamicId': '2',
          'type': 'forward',
          'contentText': '转发语',
          'member': {'name': '转发者'},
          'orig': {
            'authorName': '原作者',
            'text': '原文',
            'images': ['https://i0.hdslb.com/o.jpg'],
            'url': 'https://t.bilibili.com/9',
          },
        },
      ],
    }, baseUrl: base);

    final post = posts.single;
    expect(post.member.name, '转发者');
    expect(post.forwardedFrom?.authorName, '原作者');
    expect(post.forwardedFrom?.text, '原文');
    expect(post.forwardedFrom?.images, hasLength(1));
  });

  test('an unknown type degrades instead of dropping the post', () {
    final posts = DynamicPostRepository.decodeOnThisDay({
      'items': [
        {'dynamicId': '3', 'type': 'brand_new_server_type'},
      ],
    }, baseUrl: base);

    expect(posts, hasLength(1));
    expect(posts.single.type, DynamicType.other);
  });

  test('non-https media is dropped rather than rendered', () {
    final posts = DynamicPostRepository.decodeOnThisDay({
      'items': [
        {
          'dynamicId': '4',
          'images': ['javascript:alert(1)', 'http://insecure.test/a.jpg'],
          'url': 'javascript:alert(1)',
        },
      ],
    }, baseUrl: base);

    expect(posts.single.images, isEmpty);
    expect(posts.single.sourceUrl, isNull);
  });

  test('a malformed payload is not silently treated as an empty day', () {
    expect(
      () => DynamicPostRepository.decodeOnThisDay({
        'items': 'broken',
      }, baseUrl: base),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => DynamicPostRepository.decodeOnThisDay({
        'items': [
          {'noIdentity': true},
        ],
      }, baseUrl: base),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('an empty day is a real result, not an error', () {
    expect(
      DynamicPostRepository.decodeOnThisDay({
        'items': <Object?>[],
      }, baseUrl: base),
      isEmpty,
    );
  });
}
