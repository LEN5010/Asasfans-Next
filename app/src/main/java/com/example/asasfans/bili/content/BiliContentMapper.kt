package com.example.asasfans.bili.content

import androidx.core.text.HtmlCompat
import com.example.asasfans.bili.network.*
import com.example.asasfans.core.model.*
import com.example.asasfans.core.network.VideoPage
import kotlinx.serialization.json.*

/** Wire DTOs stop here. Unknown fields remain unknown rather than invented zero statistics/tags. */
internal object BiliContentMapper {
    fun detail(data: JsonObject, bvid: String): VideoDetails {
        if (data.text("bvid") != bvid) throw AppFailure.InvalidResponse()
        val owner = data.requireObject("owner")
        val stats = data.obj("stat")
        val video = Video(
            ContentId.bilibili(bvid), data.text("title").ifBlank { bvid },
            Creator(id = owner.positive("mid").toString(), name = owner.text("name"), avatarUrl = httpsUrl(owner.text("face"))),
            coverUrl = httpsUrl(data.text("pic")), description = data.text("desc"), category = data.text("tname"),
            publishedAtMs = milliseconds(data.number("pubdate")), durationMs = milliseconds(data.number("duration")),
            views = count(stats?.number("view")), likes = count(stats?.number("like")),
        )
        val parts = data.array("pages")?.map { value ->
            val part = value as? JsonObject ?: throw AppFailure.InvalidResponse()
            val number = part.positive("page")
            if (number > Int.MAX_VALUE) throw AppFailure.InvalidResponse()
            VideoPart(part.positive("cid"), number.toInt(), part.text("part"), milliseconds(part.number("duration")))
        } ?: throw AppFailure.InvalidResponse()
        if (parts.isEmpty() || parts.distinctBy { it.id }.size != parts.size ||
            parts.distinctBy { it.number }.size != parts.size) throw AppFailure.InvalidResponse()
        return VideoDetails(video, data.positive("aid"), parts.sortedBy { it.number })
    }

    fun search(data: JsonObject, page: Int): VideoPage {
        if (data.number("page") != page.toLong()) throw AppFailure.InvalidResponse()
        val total = count(data.number("numResults"))
        val items = data.array("result") ?: if (total == 0L) JsonArray(emptyList()) else throw AppFailure.InvalidResponse()
        val videos = items.map { value ->
            val item = value as? JsonObject ?: throw AppFailure.InvalidResponse()
            val bvid = responseBvid(item.text("bvid"))
            Video(ContentId.bilibili(bvid), plainTitle(item.text("title")).ifBlank { bvid },
                Creator(id = item.positive("mid").toString(), name = item.text("author")),
                coverUrl = httpsUrl(item.text("pic")), description = item.text("description"), category = item.text("typename"),
                tags = (item["tag"] as? JsonPrimitive)?.contentOrNull?.split(',')?.map(String::trim)?.filter(String::isNotEmpty),
                publishedAtMs = milliseconds(item.number("pubdate")), durationMs = duration(item.text("duration")),
                views = count(item.number("play")), likes = count(item.number("like")),
            )
        }.distinctBy { it.id }
        val pages = count(data.number("numPages"))
        val hasMore = page < 50 && items.isNotEmpty() && when {
            pages != null -> page < pages
            total != null -> page.toLong() * 20 < total
            else -> items.size >= 20
        }
        return VideoPage(videos, page, total, hasMore)
    }

    fun archive(data: JsonObject, mid: Long, page: Int): VideoPage {
        val paging = data.requireObject("page")
        if (paging.number("pn") != page.toLong()) throw AppFailure.InvalidResponse()
        val items = data.requireObject("list").array("vlist") ?: throw AppFailure.InvalidResponse()
        val videos = items.map { value ->
            val item = value as? JsonObject ?: throw AppFailure.InvalidResponse()
            val bvid = responseBvid(item.text("bvid"))
            if (item.number("mid") != mid) throw AppFailure.InvalidResponse()
            Video(ContentId.bilibili(bvid), item.text("title").ifBlank { bvid },
                Creator(id = mid.toString(), name = item.text("author")),
                coverUrl = httpsUrl(item.text("pic")), description = item.text("description"),
                publishedAtMs = milliseconds(item.number("created")), durationMs = duration(item.text("length")),
                views = count(item.number("play")),
            )
        }.distinctBy { it.id }
        val total = count(paging.number("count"))
        return VideoPage(videos, page, total, items.isNotEmpty() &&
            if (total != null) page.toLong() * 20 < total else items.size >= 20)
    }

    fun comments(data: JsonObject, page: Int): CommentPage {
        val paging = data.requireObject("page")
        if (paging.number("num") != page.toLong()) throw AppFailure.InvalidResponse()
        val replies = data.array("replies").orEmpty()
        val rows = linkedMapOf<Long, ReadOnlyComment>()
        fun add(value: JsonElement, pinned: Boolean = false, hot: Boolean = false) {
            val item = value as? JsonObject ?: throw AppFailure.InvalidResponse()
            val member = item.requireObject("member")
            val id = item.positive("rpid")
            rows.putIfAbsent(id, ReadOnlyComment(id, member.text("mid"), member.text("uname"),
                httpsUrl(member.text("avatar")), item.requireObject("content").text("message"),
                milliseconds(item.number("ctime")), count(item.number("like")), pinned, hot))
        }
        if (page == 1) {
            data.obj("upper")?.obj("top")?.let { add(it, pinned = true) }
            data.array("hots")?.forEach { add(it, hot = true) }
        }
        replies.forEach { add(it) }
        val total = count(paging.number("count"))
        val size = paging.positive("size")
        return CommentPage(rows.values.toList(), page, total,
            replies.isNotEmpty() && if (total != null) page.toLong() < ((total - 1) / size + 1) else replies.size >= size)
    }

    fun playback(data: JsonObject, nowMs: Long): PlaybackStreams {
        val dash = data.obj("dash")
        fun tracks(kind: String) = dash?.array(kind)?.mapNotNull { value ->
            val item = value as? JsonObject ?: throw AppFailure.InvalidResponse()
            val urls = urls(item, "baseUrl", "base_url")
            val quality = item.positive("id")
            if (quality > Int.MAX_VALUE) throw AppFailure.InvalidResponse()
            if (urls.isEmpty()) null else MediaTrack(quality.toInt(), item.text("codecs"),
                item.text("mimeType").ifBlank { item.text("mime_type") }.ifBlank { "$kind/mp4" },
                count(item.number("bandwidth")) ?: 0, urls)
        }.orEmpty()
        val videos = tracks("video")
        val audios = tracks("audio")
        val segments = data.array("durl")?.mapIndexed { index, value ->
            val item = value as? JsonObject ?: throw AppFailure.InvalidResponse()
            val urls = urls(item, "url")
            if (urls.isEmpty()) throw AppFailure.InvalidResponse()
            MediaSegment((item.number("order") ?: (index + 1).toLong()).toInt(), count(item.number("length")) ?: 0, urls)
        }.orEmpty().sortedBy { it.order }
        if (videos.isEmpty() && segments.isEmpty()) throw AppFailure.Unavailable()
        val returned = data.number("quality")?.takeIf { it in 1..Int.MAX_VALUE }?.toInt() ?: 0
        val playable = videos.map { it.quality }.toSet() + if (segments.isNotEmpty() && returned > 0) setOf(returned) else emptySet()
        val labels = data.array("accept_description").orEmpty()
        val options = data.array("accept_quality").orEmpty().mapIndexedNotNull { index, value ->
            val qn = (value as? JsonPrimitive)?.intOrNull?.takeIf { it > 0 } ?: return@mapIndexedNotNull null
            val label = (labels.getOrNull(index) as? JsonPrimitive)?.contentOrNull?.takeIf(String::isNotBlank) ?: qualityLabel(qn)
            QualityOption(qn, label, qn in playable)
        }.toMutableList()
        playable.filter { qn -> options.none { it.id == qn } }.forEach { options += QualityOption(it, qualityLabel(it), true) }
        return PlaybackStreams(videos, audios, segments, options.distinctBy { it.id }.sortedByDescending { it.id },
            returned, count(data.number("timelength")) ?: 0, nowMs)
    }

    private fun urls(item: JsonObject, vararg primaryNames: String): List<String> {
        val primary = primaryNames.map { item.text(it) }
        val backups = (item.array("backupUrl") ?: item.array("backup_url")).orEmpty()
            .mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
        return (primary + backups).map(::httpsUrl).filter(String::isNotEmpty).distinct().take(4)
    }

    internal fun duration(value: String): Long {
        val parts = value.trim().split(':')
        if (parts.size !in 1..3) return 0
        var seconds = 0L
        for (part in parts) {
            val number = part.trim().toLongOrNull()?.takeIf { it >= 0 } ?: return 0
            if (seconds > (Long.MAX_VALUE / 1000 - number) / 60 || number > Long.MAX_VALUE / 1000) return 0
            seconds = seconds * 60 + number
        }
        return milliseconds(seconds)
    }

    private fun plainTitle(value: String): String = HtmlCompat.fromHtml(value, HtmlCompat.FROM_HTML_MODE_LEGACY).toString().trim()
    private fun responseBvid(value: String): String = try { requireBvid(value) }
        catch (_: AppFailure.InvalidInput) { throw AppFailure.InvalidResponse() }
}
