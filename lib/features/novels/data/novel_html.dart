import '../domain/novel_repository.dart';

final _asset = RegExp(
  r'^(?:assets/|/api/novels/assets/)([a-f0-9]{64}\.[A-Za-z0-9]+)$',
);

/// Resolves an image location from the novel archive.
///
/// The server writes frozen attachments as `/api/novels/assets/<sha256>.<ext>`,
/// relative to its own API root. The deployed API sits under a route prefix
/// (`…/dynamics/api/`), so the file name is re-based onto `novels/assets/`
/// under that base instead of resolving the root-relative path, which would
/// drop the prefix. Anything else must already be an absolute HTTPS URL.
Uri? novelAssetUri(String raw, Uri baseUrl) {
  final value = raw.trim();
  final local = _asset.firstMatch(value);
  if (local != null) return baseUrl.resolve('novels/assets/${local[1]}');
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

final _token = RegExp(
  r'''<!--[\s\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:[^>"']|"[^"]*"|'[^']*')*)>''',
);
final _entity = RegExp(r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]+);');
final _space = RegExp(r'[ \t\n\r\f]+');
final _headingTag = RegExp(r'^h([1-6])$');

const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'middot': '·',
  'ldquo': '\u201c',
  'rdquo': '\u201d',
  'lsquo': '\u2018',
  'rsquo': '\u2019',
};

/// Tags that end the current run of text. Anything not listed here and not
/// handled below is treated as inline: its text flows into the paragraph.
const _breaking = {
  'p',
  'div',
  'section',
  'article',
  'header',
  'footer',
  'figure',
  'figcaption',
  'table',
  'thead',
  'tbody',
  'tr',
  'td',
  'th',
  'dl',
  'dt',
  'dd',
};

/// Converts the archive's reading HTML into layout blocks.
///
/// The server already reduces a work to paragraphs, headings, quotes, lists,
/// preformatted text, rules, line breaks and images; this keeps that structure
/// and drops inline formatting to plain text.
List<NovelBlock> novelBlocksFromHtml(String html, {required Uri baseUrl}) {
  final builder = _BlockBuilder(baseUrl);
  var index = 0;
  for (final match in _token.allMatches(html)) {
    builder.text(html.substring(index, match.start));
    index = match.end;
    final name = match[2];
    if (name == null) continue;
    builder.tag(
      name.toLowerCase(),
      closing: match[1] == '/',
      attributes: match[3]!,
    );
  }
  builder.text(html.substring(index));
  return builder.finish();
}

String decodeHtmlEntities(String value) =>
    value.replaceAllMapped(_entity, (match) {
      final body = match[1]!;
      if (!body.startsWith('#')) return _named[body] ?? match[0]!;
      final code = body[1] == 'x' || body[1] == 'X'
          ? int.parse(body.substring(2), radix: 16)
          : int.parse(body.substring(1));
      final valid =
          code > 0 && code <= 0x10ffff && (code < 0xd800 || code > 0xdfff);
      return String.fromCharCode(valid ? code : 0xfffd);
    });

class _BlockBuilder {
  _BlockBuilder(this.baseUrl);
  final Uri baseUrl;
  final _blocks = <NovelBlock>[];
  final _buffer = StringBuffer();
  final _lists = <({bool ordered, int count})>[];
  int _heading = 0;
  int _quote = 0;
  int _pre = 0;
  String? _marker;

  void text(String raw) {
    if (raw.isEmpty) return;
    _buffer.write(
      decodeHtmlEntities(
        _pre > 0 ? raw.replaceAll('\r\n', '\n') : raw.replaceAll(_space, ' '),
      ),
    );
  }

  void tag(String name, {required bool closing, required String attributes}) {
    final heading = _headingTag.firstMatch(name);
    if (name == 'br') {
      _buffer.write('\n');
    } else if (name == 'hr') {
      _flush();
      _blocks.add(const NovelDividerBlock());
    } else if (name == 'img') {
      final url = novelAssetUri(_attribute(attributes, 'src') ?? '', baseUrl);
      if (url == null) return;
      _flush();
      _blocks.add(
        NovelImageBlock(url, alt: _attribute(attributes, 'alt') ?? ''),
      );
    } else if (heading != null) {
      _flush();
      _heading = closing ? 0 : int.parse(heading[1]!);
    } else if (name == 'pre') {
      _flush();
      _pre = closing ? (_pre > 0 ? _pre - 1 : 0) : _pre + 1;
    } else if (name == 'blockquote') {
      _flush();
      _quote = closing ? (_quote > 0 ? _quote - 1 : 0) : _quote + 1;
    } else if (name == 'ul' || name == 'ol') {
      _flush();
      if (!closing) {
        _lists.add((ordered: name == 'ol', count: 0));
      } else if (_lists.isNotEmpty) {
        _lists.removeLast();
      }
      _marker = null;
    } else if (name == 'li') {
      _flush();
      _marker = null;
      if (closing) return;
      if (_lists.isEmpty) {
        _marker = '• ';
        return;
      }
      final list = _lists.removeLast();
      final count = list.count + 1;
      _lists.add((ordered: list.ordered, count: count));
      _marker = list.ordered ? '$count. ' : '• ';
    } else if (_breaking.contains(name)) {
      _flush();
    }
  }

  List<NovelBlock> finish() {
    _flush();
    return List.unmodifiable(_blocks);
  }

  void _flush() {
    final raw = _buffer.toString();
    _buffer.clear();
    if (raw.trim().isEmpty) return;
    if (_pre > 0) {
      _add(
        raw.replaceAll(RegExp(r'^\n+|\n+$'), ''),
        NovelTextStyle.preformatted,
      );
      return;
    }
    // One break is a line break inside a paragraph; a blank line starts a
    // new paragraph, as the server's own reading layout does.
    final lines = raw.split('\n').map((line) => line.trim()).toList();
    final paragraph = <String>[];
    for (final line in [...lines, '']) {
      if (line.isNotEmpty) {
        paragraph.add(line);
      } else if (paragraph.isNotEmpty) {
        _add(
          paragraph.join('\n'),
          _quote > 0 ? NovelTextStyle.quote : NovelTextStyle.paragraph,
        );
        paragraph.clear();
      }
    }
  }

  void _add(String text, NovelTextStyle style) {
    final marker = _marker;
    _marker = null;
    final value = marker == null ? text : '$marker$text';
    _blocks.add(
      _heading > 0 && style != NovelTextStyle.preformatted
          ? NovelTextBlock.heading(value, _heading)
          : NovelTextBlock(value, style: style),
    );
  }

  static String? _attribute(String attributes, String name) {
    final match = RegExp(
      '(?:^|\\s)$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s"\'>]+))',
      caseSensitive: false,
    ).firstMatch(attributes);
    if (match == null) return null;
    return decodeHtmlEntities(match[1] ?? match[2] ?? match[3]!);
  }
}
