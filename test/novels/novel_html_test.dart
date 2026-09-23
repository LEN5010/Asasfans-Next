import 'package:asasfans_next/features/novels/data/novel_html.dart';
import 'package:asasfans_next/features/novels/domain/novel_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Uri.parse('https://example.test/dynamics/api/');
  final hash = 'a' * 64;

  List<NovelBlock> blocks(String html) =>
      novelBlocksFromHtml(html, baseUrl: base);

  test('reads the server reading layout into paragraphs and breaks', () {
    // Shape of formatNovelReadingHtml output: annotated paragraphs, one
    // break inside a paragraph, a rule, and a nested container.
    expect(
      blocks(
        '<p id="np-v1-x-1" data-novel-paragraph="0">第一行<br>第二行</p>'
        '<hr>'
        '<div><p>容器里的段落</p></div>',
      ),
      const [
        NovelTextBlock('第一行\n第二行'),
        NovelDividerBlock(),
        NovelTextBlock('容器里的段落'),
      ],
    );
  });

  test('a blank line between breaks starts a new paragraph', () {
    expect(blocks('甲<br><br>  <br>乙<br/>丙'), const [
      NovelTextBlock('甲'),
      NovelTextBlock('乙\n丙'),
    ]);
  });

  test('headings, quotes, lists and preformatted text keep their role', () {
    expect(
      blocks(
        '<h2>第一章</h2>'
        '<blockquote><p>引用一</p><p>引用二</p></blockquote>'
        '<ol><li><p>一</p></li><li>二</li></ol>'
        '<ul><li>点</li></ul>'
        '<pre>  缩进\n保留</pre>',
      ),
      const [
        NovelTextBlock.heading('第一章', 2),
        NovelTextBlock('引用一', style: NovelTextStyle.quote),
        NovelTextBlock('引用二', style: NovelTextStyle.quote),
        NovelTextBlock('1. 一'),
        NovelTextBlock('2. 二'),
        NovelTextBlock('• 点'),
        NovelTextBlock('  缩进\n保留', style: NovelTextStyle.preformatted),
      ],
    );
  });

  test('inline and unknown tags contribute only their text', () {
    expect(
      blocks(
        '<p>她<strong>笑</strong>了，<a href="https://x.test/">链接</a>'
        '<custom-tag data-x="1">未知</custom-tag><!-- 注释 --></p>',
      ),
      const [NovelTextBlock('她笑了，链接未知')],
    );
  });

  test('decodes named and numeric entities', () {
    expect(
      blocks('<p>a &amp; b &lt;c&gt; &#20320;&#x597D; &nbsp;&hellip;</p>'),
      [const NovelTextBlock('a & b <c> 你好 \u00a0…')],
    );
    expect(decodeHtmlEntities('&unknown; &#0;'), '&unknown; \ufffd');
  });

  test('images split the paragraph and resolve under the API prefix', () {
    expect(
      blocks(
        '<p>前文<img src="/api/novels/assets/$hash.webp" alt="插图">后文</p>'
        '<p><img src="https://img.test/a.png"></p>'
        '<p><img src="http://img.test/b.png"><img src="javascript:x"></p>',
      ),
      [
        const NovelTextBlock('前文'),
        NovelImageBlock(
          Uri.parse(
            'https://example.test/dynamics/api/novels/assets/$hash.webp',
          ),
          alt: '插图',
        ),
        const NovelTextBlock('后文'),
        NovelImageBlock(Uri.parse('https://img.test/a.png')),
      ],
    );
  });

  test('asset paths keep the deployed route prefix', () {
    expect(
      novelAssetUri('/api/novels/assets/$hash.png', base).toString(),
      'https://example.test/dynamics/api/novels/assets/$hash.png',
    );
    expect(
      novelAssetUri('assets/$hash.png', base).toString(),
      'https://example.test/dynamics/api/novels/assets/$hash.png',
    );
    expect(novelAssetUri('/api/novels/assets/short.png', base), isNull);
    expect(novelAssetUri('https://u:p@img.test/a.png', base), isNull);
  });

  test('empty or whitespace-only markup yields no blocks', () {
    expect(blocks(''), isEmpty);
    expect(blocks('<p> </p>\n<div>\n</div>'), isEmpty);
  });
}
