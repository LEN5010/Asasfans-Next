enum ToolCategory { content, community, utility }

class CommunityTool {
  const CommunityTool(this.id, this.name, this.url, this.category);
  final String id;
  final String name;
  final String url;
  final ToolCategory category;
}

const communityTools = [
  CommunityTool(
    'studio',
    '录音棚',
    'https://studio.asoul.us.kg',
    ToolCategory.content,
  ),
  CommunityTool(
    'calendar',
    'A-SOUL 日历',
    'https://asoul.love',
    ToolCategory.content,
  ),
  CommunityTool(
    'dynamics',
    '动态站',
    'https://len5010.top/dynamics/',
    ToolCategory.content,
  ),
  CommunityTool(
    'fanart',
    '二创站',
    'https://len5010.top/fanart',
    ToolCategory.content,
  ),
  CommunityTool(
    'navigation',
    '社区导航',
    'https://nav.asoul.us.kg',
    ToolCategory.community,
  ),
  CommunityTool(
    'cnki',
    '枝网查重',
    'https://cnki.asoul.us.kg',
    ToolCategory.utility,
  ),
  CommunityTool(
    'book',
    '枝江小作文',
    'https://book.asoul.us.kg',
    ToolCategory.content,
  ),
  CommunityTool(
    'rank',
    '查重排行榜',
    'https://cnki.asoul.us.kg/rank',
    ToolCategory.community,
  ),
  CommunityTool(
    'wiki',
    'A-SOUL Wiki',
    'https://wiki.asoul.us.kg/',
    ToolCategory.community,
  ),
  CommunityTool(
    'recordings',
    '录播站',
    'https://nf.asoul-rec.com',
    ToolCategory.content,
  ),
  CommunityTool(
    'bili-tools',
    'BiliTools',
    'https://www.bilitools.top/t/4/',
    ToolCategory.utility,
  ),
  CommunityTool(
    'subtitles',
    '字幕工具',
    'https://zimu.live/',
    ToolCategory.utility,
  ),
  CommunityTool('aicu', 'AICU', 'https://aicu.cc', ToolCategory.utility),
  CommunityTool('vtbs', 'VTBs', 'https://vtbs.moe', ToolCategory.community),
];
