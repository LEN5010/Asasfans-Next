package com.example.asasfans.core.network

import com.example.asasfans.core.model.*
import kotlinx.serialization.json.*
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl

data class VideoPage(val videos: List<Video>, val page: Int, val total: Long?, val hasMore: Boolean)

/** Contract verified against the community endpoint: tags work; title queries are ignored. */
class CommunityVideoSource(
    private val http: JsonHttpClient,
    private val endpoint: HttpUrl = ENDPOINT.toHttpUrl(),
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    suspend fun load(query: QuerySpec, page: Int): VideoPage {
        val root = http.get(url(query, page))
        return decodePage(root, page)
    }

    internal fun url(query: QuerySpec, page: Int): HttpUrl {
        require(page in 1..100_000)
        if (query.keyword.isNotBlank()) throw AppFailure.InvalidInput("社区来源不支持标题搜索，请使用 B 站搜索或标签筛选")
        if (query.maxDurationMs != null) throw AppFailure.InvalidInput("此来源不支持远程时长筛选")
        val conditions = mutableListOf<String>()
        if (query.tags.isNotEmpty()) {
            if (query.tags.any { value -> value.any { it in ".+~" } }) throw AppFailure.InvalidInput("此来源不支持含 .、+ 或 ~ 的标签")
            conditions += "tag.${query.tags.joinToString("+")}.AND"
        }
        query.creatorId?.let {
            if (it.toLongOrNull()?.let { id -> id > 0 } != true) throw AppFailure.InvalidInput("UP UID 格式不正确")
            conditions += "mid.$it.OR"
        }
        query.days?.let {
            val end = nowMs() / 1000
            conditions += "pubdate.${(end - it.toLong() * 86400).coerceAtLeast(0)}+$end.BETWEEN"
        }
        return endpoint.newBuilder()
            .addQueryParameter("order", if (query.order == VideoOrder.NEWEST) "pubdate" else "score")
            .addQueryParameter("q", conditions.joinToString("~"))
            .addQueryParameter("copyright", query.copyright?.toString().orEmpty())
            .addQueryParameter("tname", "")
            .addQueryParameter("page", page.toString()).build()
    }

    companion object {
        const val ENDPOINT = "https://api.asoul.us.kg/asasfans/v2/asoul-video-interface/advanced-search"

        internal fun decodePage(root: JsonObject, requestedPage: Int): VideoPage = try {
            val data = root["data"] as? JsonObject ?: throw AppFailure.InvalidResponse()
            val actualPage = data.number("page")?.toInt() ?: requestedPage
            if (actualPage != requestedPage) throw AppFailure.InvalidResponse()
            val items = data["result"] as? JsonArray ?: throw AppFailure.InvalidResponse()
            val videos = items.map { value ->
                val item = value as? JsonObject ?: throw AppFailure.InvalidResponse()
                val bvid = item.text("bvid").takeIf(String::isNotBlank) ?: throw AppFailure.InvalidResponse()
                Video(
                    id = ContentId.bilibili(bvid), title = item.text("title").ifBlank { bvid },
                    creator = Creator(id = item.text("mid"), name = item.text("name"), avatarUrl = https(item.text("face"))),
                    coverUrl = https(item.text("pic")), description = item.text("desc"), category = item.text("tname"),
                    tags = (item["tag"] as? JsonPrimitive)?.contentOrNull?.let(ContentRuleEvaluator::parseLegacyTags),
                    publishedAtMs = milliseconds(item.number("pubdate")), durationMs = milliseconds(item.number("duration")),
                    views = item.number("view")?.takeIf { it >= 0 }, likes = item.number("like")?.takeIf { it >= 0 },
                )
            }.distinctBy { it.id }
            val total = data.number("numResults")?.takeIf { it >= 0 }
            VideoPage(videos, requestedPage, total, if (total != null) requestedPage.toLong() * 20 < total else items.isNotEmpty())
        } catch (error: IllegalArgumentException) {
            throw AppFailure.InvalidResponse()
        }

        private fun JsonObject.text(name: String) = (this[name] as? JsonPrimitive)?.contentOrNull.orEmpty()
        private fun JsonObject.number(name: String) = (this[name] as? JsonPrimitive)?.longOrNull
        private fun milliseconds(seconds: Long?): Long = seconds?.takeIf { it in 0..Long.MAX_VALUE / 1000 }?.times(1000) ?: 0
        private fun https(value: String): String = when {
            value.startsWith("//") -> "https:$value"
            value.startsWith("http://") && value.toHttpUrl().host.let { it == "hdslb.com" || it.endsWith(".hdslb.com") } -> "https://${value.removePrefix("http://")}"
            else -> value
        }
    }
}
