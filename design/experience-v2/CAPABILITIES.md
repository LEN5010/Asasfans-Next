# Capability matrix (U01 / U04)

Checked against the source on 2026-09-26 at `909b4c1` (= `7134a40` plus the screenshot harness). Every screen of the V2 design must stay inside this table. A field missing here is not shown, promised or faked.

## Channels and their real queries

| Channel | Query model | Fields the source accepts | What the current UI exposes | Not available (do not show) |
|---|---|---|---|---|
| 视频 (videos) | `CommunityVideoQuery` | `tags` (AND), `creatorId`, `withinDays`, `order` (newest / score), frozen `asOf`; the kind (全部/切片/录播) is a set of tag alternatives the pager fans out | kind segments, order (最新/最热), window (全部时间/一周内/一月内) in a menu, refresh | **no keyword**: no search field, not even a "search videos" placeholder. `creatorId` exists but has no UI entry (the creator name opens the B站 space instead); adding a creator filter would be a new feature, out of V2 scope |
| 二创 (fanart) | `FanartQuery` | `keyword` (text or author, ≤200), `characters` (multi), `kind` (二创/物料/全部), `contentType`, `category`, `sort` (newest/oldest/views/favorites; metric sorts only for video and not Douban), `source` (all/bilibili/douban) | search field, filter panel (draft, apply), two quick chip rows (members, categories), summary line for keyword + panel-only count, reset, random draw, saved queries, refresh | image **width/height are not in the model**; natural-ratio masonry cannot be claimed without them |
| 动态 (dynamics) | `DynamicQuery` | `keyword`, `memberId` (`uid:<digits>`), `type`, `from`/`to`, `sort` (newest/oldest/likes/comments) | search field, filter panel, saved queries | nothing beyond these fields |
| 小说 (novels) | `NovelQuery` | `keyword`, `scope` (全部/标题/正文/作者), `characters` (AND), `rating` (全部/全年龄/R18), `sort` (最新/最早/字数最多) | search field, filter panel, facet counts | no covers (`images` is usually empty); R18 works have no text, only metadata |

Saved queries exist for fanart, dynamics and videos (`ChannelFeed`), stored as versioned specs.

## Content fields available for display

| Type | Always | Sometimes | Never |
|---|---|---|---|
| Video (`VideoSummary`) | identity (BV), title, creator name/id | cover, avatar, category, tags, publish time, duration, views, likes | play progress, playable URL |
| Fanart (`FanartItem`) | identity, text, author name/uid, kind, type, category, member tags | images (0..n), source URL, avatar, space URL, views/favorites (video only) | image dimensions, editor's pick flag |
| Dynamic (`DynamicPost`) | identity, member, type, text | images, media (with width/height), publish time, source, counts, forwarded post | — |
| Novel (`NovelSummary`) | id/tid, title, author, rating, members, char count | excerpt (empty for R18), source, created time | cover art |
| Calendar (`CalendarEvent`) | uid, title, start/end, all-day, status (confirmed/tentative/cancelled), sequence | members, categories, description, location, source URL | push reminders (the app has in-app update records only) |

## Routes (all must stay reachable)

`/today`, `/content` → videos, `/content/{videos,fanart,dynamics,novels}`, old `/content/{latest,clips,replays}` → `/content/videos?kind=…`, `/calendar`, `/mine`, `/mine/{saved,saved/:folder,later,history,continue,bookmarks,subscriptions,calendar-follows,updates,rules,backup,credits}`. Detail pages (fanart detail, image viewer, novel reader, dynamic detail) are pushed routes, not URLs. Tools are a sheet (floating button, rail entry, and 我的 → 工具与相关站点), not a branch.

## Hand-off and "continue"

- Videos, video-type fanart and creator pages open on B站 (`ExternalLinkService`). A `ReturnContext` (one-shot, consumed once) plus the native return entry bring the user back. Return restores channel, query and the anchored item (bounded, 3 extra pages at most).
- 继续观看 (`/mine/continue`) is an existing **local record of opened items**. It is not B站 play progress and must not be labelled as such.
- "继续挑选" (planned in U19) is a separate, read-only snapshot of the last browsing context. It must never reuse a consumed `ReturnContext`.

## Things the V2 design must not claim

A global search across all channels. Video keyword search. Play progress bars. "精选/编辑推荐/热门推荐" labels (sorting is newest or source score only; "最热" is the source's own score order). Push notifications or background alerts. Cloud sync, login or avatar account centre (only a cleanup tile for an old local sign-in exists). Natural image ratios for fanart without dimensions.
