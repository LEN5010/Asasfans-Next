package com.example.asasfans.bili.content

import com.example.asasfans.bili.network.BiliGateway
import com.example.asasfans.bili.network.requireBvid
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.model.QuerySpec
import com.example.asasfans.core.model.VideoOrder
import com.example.asasfans.core.network.VideoPage

/** Read-only Bilibili boundary. Local library/subscribe writes belong to the local repositories. */
class BiliContentRepository(
    private val api: BiliGateway,
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    suspend fun creator(mid: Long): CreatorProfile {
        if (mid <= 0) throw AppFailure.InvalidInput("UP UID 不正确")
        return BiliContentMapper.creator(api.get("/x/space/wbi/acc/info", mapOf("mid" to mid.toString()),
            needsDeviceCookie = true, referer = "https://space.bilibili.com/$mid"), mid)
    }

    suspend fun detail(bvid: String): VideoDetails {
        requireBvid(bvid)
        return BiliContentMapper.detail(api.get("/x/web-interface/wbi/view", mapOf("bvid" to bvid)), bvid)
    }

    suspend fun search(query: QuerySpec, page: Int): VideoPage {
        if (query.keyword.isBlank()) throw AppFailure.InvalidInput("请输入搜索关键词")
        if (query.tags.isNotEmpty() || query.copyright != null || query.creatorId != null ||
            query.days != null || query.maxDurationMs != null) {
            throw AppFailure.InvalidInput("B 站搜索当前支持关键词和排序；标签等条件请使用对应来源的筛选")
        }
        if (page !in 1..50) throw AppFailure.InvalidInput("B 站搜索最多返回 50 页")
        val params = mapOf("search_type" to "video", "keyword" to query.keyword.trim(), "page" to page.toString(),
            "order" to if (query.order == VideoOrder.NEWEST) "pubdate" else "click")
        return BiliContentMapper.search(api.get("/x/web-interface/wbi/search/type", params, needsDeviceCookie = true), page)
    }

    suspend fun archive(mid: Long, page: Int): VideoPage {
        if (mid <= 0 || page !in 1..100_000) throw AppFailure.InvalidInput("UP UID 或页码不正确")
        val params = mapOf("mid" to mid.toString(), "pn" to page.toString(), "ps" to "20", "tid" to "0", "order" to "pubdate")
        return BiliContentMapper.archive(api.get("/x/space/wbi/arc/search", params,
            referer = "https://space.bilibili.com/$mid/video"), mid, page)
    }

    suspend fun comments(aid: Long, page: Int, order: CommentOrder = CommentOrder.LIKES): CommentPage {
        if (aid <= 0 || page !in 1..100_000) throw AppFailure.InvalidInput("评论页码或视频 ID 不正确")
        val params = mapOf("type" to "1", "oid" to aid.toString(), "pn" to page.toString(), "ps" to "20",
            "sort" to order.value, "nohot" to "0")
        return try {
            BiliContentMapper.comments(api.get("/x/v2/reply", params, signed = false), page)
        } catch (error: AppFailure.Business) {
            if (error.code == 12002) throw AppFailure.CommentsClosed() else throw error
        }
    }

    suspend fun playback(bvid: String, cid: Long, quality: Int = 0, mp4: Boolean = false): PlaybackStreams {
        requireBvid(bvid)
        if (cid <= 0 || quality < 0) throw AppFailure.InvalidInput("分 P 或清晰度不正确")
        val params = mutableMapOf("bvid" to bvid, "cid" to cid.toString(), "fnver" to "0", "fourk" to "0", "otype" to "json",
            "gaia_source" to "view-card",
            "fnval" to if (mp4) "1" else "16", "qn" to (quality.takeIf { it > 0 } ?: 80).toString())
        if (mp4) { params["platform"] = "html5"; params["high_quality"] = "1" }
        return BiliContentMapper.playback(api.get("/x/player/wbi/playurl", params,
            referer = "https://www.bilibili.com/video/$bvid"), nowMs())
    }
}
