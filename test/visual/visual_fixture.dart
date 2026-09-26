import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/novels/domain/novel_repository.dart';

/// Self-written display data for screenshots. Every name, title and post
/// here is invented for the fixture (member names aside); nothing comes from
/// the production sources or a real user. Bump [fixtureRevision] whenever
/// the content changes, so two screenshots can be compared honestly.
const fixtureRevision = 'v2-fixture-3';

/// The fixed instant every screenshot is taken at: Saturday 26 September
/// 2026, 12:00 in Shanghai.
final fixtureNow = DateTime.utc(2026, 9, 26, 4);

/// Images are served by name from generated artwork (see visual_harness).
/// The name carries the pixel size, so layout sees a real aspect ratio.
Uri art(String name) => Uri.https('fixture.invalid', '/art/$name.png');

/// Every image the fixture refers to, with its pixel size.
const fixtureImages = <String, (int, int)>{
  'land-a': (1600, 900),
  'land-b': (1920, 1080),
  'land-c': (1280, 720),
  'land-d': (1600, 1000),
  'port-a': (900, 1200),
  'port-b': (1080, 1440),
  'port-c': (800, 1100),
  'square-a': (1000, 1000),
  'square-b': (900, 900),
  'tall-a': (720, 2600),
  'wide-a': (2400, 800),
  'avatar-1': (160, 160),
  'avatar-2': (160, 160),
  'avatar-3': (160, 160),
  'avatar-4': (160, 160),
  'cover-1': (1280, 720),
  'cover-2': (1280, 720),
  'cover-3': (1280, 720),
  'cover-4': (1280, 720),
  'cover-5': (1280, 720),
  'cover-6': (1280, 720),
  'cover-7': (1280, 720),
  'cover-8': (1280, 720),
};

FanartItem _fanart(
  int id,
  String text, {
  String author = '枝江画手',
  List<String> images = const [],
  FanartContentType type = FanartContentType.image,
  FanartCategory category = FanartCategory.normal,
  List<FanartCharacter> tags = const [FanartCharacter.diana],
  String avatar = 'avatar-1',
}) => FanartItem(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '90000$id',
  ),
  text: text,
  authorName: author,
  authorUid: '1000$id',
  images: [for (final name in images) art(name)],
  kind: FanartKind.fanart,
  contentType: type,
  category: category,
  characterTags: tags,
  authorAvatarUrl: art(avatar),
  sourceUrl: Uri.https('t.bilibili.com', '/90000$id'),
);

final fixtureFanart = <FanartItem>[
  _fanart(
    1,
    '秋天的第一杯奶茶，给然然画了新衣服。枫叶和围巾的颜色调了很久，希望大家喜欢！',
    author: '小枝的调色盘',
    images: ['port-a', 'square-a', 'land-a'],
  ),
  _fanart(
    2,
    '贝拉练舞后的休息时间',
    author: '拉姐的舞鞋',
    images: ['land-b'],
    tags: [FanartCharacter.bella],
    avatar: 'avatar-2',
  ),
  _fanart(
    3,
    '一篇很短的小故事：那天晚上，直播间的弹幕像雨一样落下来，她说“今天也要好好吃饭哦”。我把这句话抄在了便签上，贴在显示器的边框，一直贴到了现在。',
    author: '晚安故事会',
    type: FanartContentType.text,
    category: FanartCategory.normal,
    tags: [FanartCharacter.diana, FanartCharacter.eileen],
    avatar: 'avatar-3',
  ),
  _fanart(
    4,
    '乃琳的长图条漫：从早到晚的一天（完整版请点开看）',
    author: '条漫练习生',
    images: ['tall-a'],
    tags: [FanartCharacter.eileen],
    avatar: 'avatar-4',
  ),
  _fanart(
    5,
    '手书动画《夏日的尾巴》完成了，去 B 站看完整版',
    author: '手书工作室',
    images: ['land-c'],
    type: FanartContentType.video,
    category: FanartCategory.handwriting,
    tags: [FanartCharacter.diana, FanartCharacter.bella],
    avatar: 'avatar-2',
  ),
  _fanart(
    6,
    '九宫格表情包合集，欢迎取用',
    author: '表情包仓库',
    images: [
      'square-a',
      'square-b',
      'port-b',
      'land-d',
      'square-a',
      'port-c',
      'square-b',
      'land-a',
      'port-a',
    ],
    tags: [FanartCharacter.simuAndSnow],
    avatar: 'avatar-1',
  ),
  _fanart(
    7,
    '',
    author: '无言的画师',
    images: ['port-c'],
    tags: [],
    avatar: 'avatar-3',
  ),
  _fanart(
    8,
    '这是一个特别特别长的标题，用来检查两行截断之后作者名和角色标签是否还能完整显示在卡片底部而不被挤掉或者重叠在一起',
    author: '名字也很长的一位二创作者（测试用）',
    images: ['wide-a'],
    tags: [
      FanartCharacter.diana,
      FanartCharacter.bella,
      FanartCharacter.eileen,
    ],
    avatar: 'avatar-4',
  ),
];

CommunityVideo _video(
  int id,
  String title, {
  String creator = '切片 man',
  String cover = 'cover-1',
  int minutes = 12,
  int views = 12000,
  int hoursAgo = 3,
  String category = '虚拟主播',
}) => CommunityVideo(
  identity: ContentIdentity(
    source: ContentSource.bilibiliVideo,
    value: 'BV1fixture$id',
  ),
  title: title,
  creatorName: creator,
  creatorId: '2000$id',
  coverUrl: art(cover),
  creatorAvatarUrl: art('avatar-${id % 4 + 1}'),
  category: category,
  tags: const ['直播切片'],
  publishedAt: fixtureNow.subtract(Duration(hours: hoursAgo)),
  duration: Duration(minutes: minutes, seconds: 17),
  viewCount: views,
  likeCount: views ~/ 10,
  rankScore: 1,
);

final fixtureVideos = <CommunityVideo>[
  _video(1, '【嘉然】周六晚间杂谈：秋天到了要吃什么', cover: 'cover-1', minutes: 18),
  _video(
    2,
    '【贝拉】舞蹈练习室花絮合集，第三段太帅了',
    creator: '舞蹈切片组',
    cover: 'cover-2',
    minutes: 7,
    hoursAgo: 5,
  ),
  _video(
    3,
    '【乃琳】读信环节完整版',
    creator: '乃琳的信箱',
    cover: 'cover-3',
    minutes: 41,
    hoursAgo: 9,
  ),
  _video(
    4,
    '【A-SOUL】团播名场面：一起玩猜歌游戏结果全员翻车，笑到停不下来的四十分钟精华剪辑版本',
    creator: '团播切片站',
    cover: 'cover-4',
    minutes: 39,
    hoursAgo: 20,
  ),
  _video(
    5,
    '【心宜】新曲首唱',
    creator: '歌切小铺',
    cover: 'cover-5',
    minutes: 4,
    hoursAgo: 26,
  ),
  _video(
    6,
    '【思诺】游戏直播高光',
    creator: '游戏切片',
    cover: 'cover-6',
    minutes: 15,
    hoursAgo: 30,
  ),
  _video(7, '【嘉然】手工课：做一个会发光的南瓜灯', cover: 'cover-7', minutes: 22, hoursAgo: 40),
  _video(
    8,
    '【贝拉 乃琳】双人电台第十二期',
    creator: '电台存档',
    cover: 'cover-8',
    minutes: 58,
    hoursAgo: 50,
  ),
];

const _diana = DynamicMember(
  id: 'uid:672328094',
  name: '嘉然今天吃什么',
  bilibiliUid: '672328094',
);
const _bella = DynamicMember(
  id: 'uid:672353429',
  name: '贝拉kira',
  bilibiliUid: '672353429',
);

final fixtureDynamics = <DynamicPost>[
  DynamicPost(
    identity: const ContentIdentity(
      source: ContentSource.bilibiliDynamic,
      value: '800001',
    ),
    member: _diana,
    type: DynamicType.image,
    text: '今天去公园散步，看到了好多落叶，捡了一片最红的夹在本子里。晚上八点直播见～',
    images: [art('land-a'), art('port-a'), art('square-a')],
    publishedAt: DateTime.utc(2023, 9, 26, 10),
    sourceUrl: Uri.https('t.bilibili.com', '/800001'),
    likeCount: 12034,
    commentCount: 1502,
    forwardCount: 88,
  ),
  DynamicPost(
    identity: const ContentIdentity(
      source: ContentSource.bilibiliDynamic,
      value: '800002',
    ),
    member: _bella,
    type: DynamicType.forward,
    text: '转发一下，大家记得来看！',
    images: const [],
    publishedAt: DateTime.utc(2023, 9, 25, 12),
    sourceUrl: Uri.https('t.bilibili.com', '/800002'),
    likeCount: 5020,
    commentCount: 301,
    forwardCount: 44,
    forwardedFrom: ForwardedPost(
      authorName: 'A-SOUL_Official',
      text: '本周六晚八点，A-SOUL 秋日团播，一起来聊聊这个夏天发生的故事。',
      images: [art('land-b')],
      type: DynamicType.image,
      publishedAt: DateTime.utc(2023, 9, 24, 12),
    ),
  ),
  DynamicPost(
    identity: const ContentIdentity(
      source: ContentSource.bilibiliDynamic,
      value: '800003',
    ),
    member: _diana,
    type: DynamicType.text,
    text:
        '写给大家的一段长长的话：\n这个月过得好快，谢谢每一个陪我聊天的人。有时候直播结束了还会想，今天是不是说得太多了，又或者说得太少了。不过没关系，下次见面再慢慢说吧。[嘉然_比心]',
    images: const [],
    publishedAt: DateTime.utc(2022, 9, 26, 14),
    sourceUrl: Uri.https('t.bilibili.com', '/800003'),
    likeCount: 30211,
    commentCount: 4020,
    forwardCount: 312,
  ),
];

NovelSummary _novel(
  int id,
  String title, {
  String author = '书页间',
  NovelRating rating = NovelRating.sfw,
  int chars = 12000,
  String excerpt = '',
  List<NovelCharacter> characters = const [NovelCharacter.diana],
}) => NovelSummary(
  id: 'n$id',
  sourceTid: '3000$id',
  title: title,
  authorName: author,
  rating: rating,
  characters: characters,
  charCount: chars,
  excerpt: excerpt,
  images: const [],
  sourceUrl: Uri.https('www.douban.com', '/group/topic/3000$id/'),
  createdAt: DateTime(2024, 3, id),
);

final fixtureNovels = <NovelSummary>[
  _novel(
    1,
    '便签上的晚安',
    excerpt: '那天晚上，直播间的弹幕像雨一样落下来。她说今天也要好好吃饭哦，我把这句话抄在了便签上……',
    chars: 8200,
  ),
  _novel(
    2,
    '舞鞋与雨天（上）',
    author: '雨后',
    excerpt: '排练室的灯只亮了一半，镜子里映出一个还在练习的身影。',
    characters: [NovelCharacter.bella],
    chars: 23100,
  ),
  _novel(
    3,
    '一封没有寄出的信',
    author: '信纸',
    excerpt: '亲爱的乃琳：写这封信的时候，窗外正在下今年的第一场雪。',
    characters: [NovelCharacter.eileen],
    chars: 5400,
  ),
  _novel(
    4,
    '受限作品（仅显示信息）',
    author: '匿名',
    rating: NovelRating.nsfw,
    characters: [NovelCharacter.diana, NovelCharacter.bella],
    chars: 31000,
  ),
];

NovelDetail fixtureNovelDetail(NovelSummary summary) => NovelDetail(
  summary: summary,
  contentVisible: !summary.isR18,
  blocks: summary.isR18
      ? const []
      : const [
          NovelTextBlock.heading('第一章 便签', 2),
          NovelTextBlock('那天晚上，直播间的弹幕像雨一样落下来。她说“今天也要好好吃饭哦”，声音软软的，像刚出炉的面包。'),
          NovelTextBlock(
            '我把这句话抄在了一张黄色的便签上，贴在显示器的边框。后来换了新的显示器，便签也跟着搬了家。它的边角已经卷起来了，字迹也有点晕开，可我一直没舍得换。',
          ),
          NovelTextBlock('“好好吃饭”是很普通的一句话。', style: NovelTextStyle.quote),
          NovelTextBlock(
            '普通到每个人都听过，普通到很少有人真的放在心上。可是在那段每天加班到深夜的日子里，这句普通的话成了我下班路上唯一记得的事情。便利店的灯总是亮着，我会买一个饭团，站在门口慢慢吃完，然后再走回家。',
          ),
          NovelDividerBlock(),
          NovelTextBlock.heading('第二章 晚安', 2),
          NovelTextBlock(
            '后来我也学会了在睡前说一句晚安。对着空荡荡的房间，对着还没关掉的屏幕，对着那张便签。说出来的时候，好像这一天就真的可以结束了。',
          ),
        ],
  warnings: summary.isR18 ? const ['R18'] : const [],
  externalLinks: const [],
  primaryKind: NovelPrimaryKind.main,
  externalCharCount: 0,
);

CalendarEvent _event(
  String uid,
  String title, {
  required DateTime start,
  Duration length = const Duration(hours: 2),
  EventStatus status = EventStatus.confirmed,
  List<String> members = const [],
  List<String> categories = const ['直播'],
  bool allDay = false,
  int sequence = 0,
}) => CalendarEvent(
  uid: uid,
  title: title,
  start: start,
  end: start.add(length),
  allDay: allDay,
  status: status,
  members: members,
  categories: categories,
  sequence: sequence,
);

/// Times are UTC; Shanghai is UTC+8.
final fixtureEvents = <CalendarEvent>[
  _event(
    'e1',
    '嘉然 · 周六晚间杂谈',
    start: DateTime.utc(2026, 9, 26, 12),
    members: ['嘉然'],
  ),
  _event(
    'e2',
    '贝拉 · 舞蹈直播（改期）',
    start: DateTime.utc(2026, 9, 26, 14),
    members: ['贝拉'],
    sequence: 2,
  ),
  _event(
    'e3',
    '乃琳 · 读信电台',
    start: DateTime.utc(2026, 9, 27, 11),
    members: ['乃琳'],
  ),
  _event(
    'e4',
    '心宜 · 游戏直播',
    start: DateTime.utc(2026, 9, 28, 12),
    members: ['心宜'],
    status: EventStatus.cancelled,
  ),
  _event(
    'e5',
    'A-SOUL · 秋日团播',
    start: DateTime.utc(2026, 10, 3, 12),
    length: const Duration(hours: 3),
    members: ['A-SOUL'],
  ),
  _event(
    'e6',
    '思诺 · 生日会',
    start: DateTime.utc(2026, 9, 30, 12),
    members: ['思诺'],
    categories: ['生日'],
  ),
  _event(
    'e7',
    '嘉然 · 手工课',
    start: DateTime.utc(2026, 9, 22, 12),
    members: ['嘉然'],
  ),
];

/// Repositories that answer from the fixture and never touch the network.
/// [fail] makes every first page throw, for the error-state screenshots.
class FixtureFanart implements FanartRepository {
  FixtureFanart({this.items, this.fail = false});
  final List<FanartItem>? items;
  final bool fail;
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    if (fail) throw const ApiFailure(ApiFailureKind.offline);
    return FanartPage(items: items ?? fixtureFanart, snapshotId: 'fixture');
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => (items ?? fixtureFanart).firstOrNull;
}

class FixtureVideos implements CommunityVideoRepository {
  FixtureVideos({this.items, this.fail = false});
  final List<CommunityVideo>? items;
  final bool fail;
  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    if (fail) throw const ApiFailure(ApiFailureKind.offline);
    // The pager fans channel alternatives out; one of them answers.
    final answers = query.tags.isEmpty || query.tags.single == '直播剪辑';
    return CommunityVideoPage(
      videos: answers ? (items ?? fixtureVideos) : const [],
      page: page,
      hasMore: false,
    );
  }
}

class FixtureDynamics implements DynamicRepository {
  FixtureDynamics({this.fail = false});
  final bool fail;
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    if (fail) throw const ApiFailure(ApiFailureKind.offline);
    return DynamicPage(items: fixtureDynamics);
  }

  @override
  Future<List<DynamicMember>> members() async => const [_diana, _bella];

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => [fixtureDynamics.first, fixtureDynamics.last];
}

class FixtureNovels implements NovelRepository {
  @override
  Future<NovelPage> search({
    NovelQuery query = const NovelQuery(),
    int offset = 0,
    RequestCancellation? cancellation,
  }) async => NovelPage(
    items: fixtureNovels,
    total: fixtureNovels.length,
    offset: 0,
    limit: 24,
  );

  @override
  Future<NovelDetail> detail(
    String sourceTid, {
    RequestCancellation? cancellation,
  }) async => fixtureNovelDetail(
    fixtureNovels.firstWhere((novel) => novel.sourceTid == sourceTid),
  );

  @override
  Future<NovelFacets> facets() async => const NovelFacets(
    total: 4,
    byRating: {NovelRating.sfw: 3, NovelRating.nsfw: 1},
  );
}

class FixtureCalendar implements CalendarRepository {
  FixtureCalendar({this.list, this.stale = false, this.fail = false});
  final List<CalendarEvent>? list;
  final bool stale;
  final bool fail;
  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    if (fail) throw const ApiFailure(ApiFailureKind.offline);
    return CalendarSnapshot(
      events: list ?? fixtureEvents,
      fetchedAt: fixtureNow.subtract(Duration(hours: stale ? 30 : 0)),
      isStale: stale,
    );
  }
}
