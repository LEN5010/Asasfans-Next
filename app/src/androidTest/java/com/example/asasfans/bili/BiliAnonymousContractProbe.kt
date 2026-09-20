package com.example.asasfans.bili

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.asasfans.bili.account.BiliCredentials
import com.example.asasfans.bili.content.BiliContentRepository
import com.example.asasfans.bili.content.VideoDetails
import com.example.asasfans.bili.network.BiliGateway
import com.example.asasfans.bili.network.HttpBiliTransport
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.model.QuerySpec
import com.example.asasfans.core.network.JsonHttpClient
import java.io.File
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*
import okhttp3.OkHttpClient
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Manual probe, excluded from normal deterministic CI. Reports outcomes, NOT player/UI acceptance.
 * Enable with -Pandroid.testInstrumentationRunnerArguments.biliLiveProbe=true and this class filter.
 * No vault/account is opened; evidence excludes device cookies, media URLs and raw responses.
 */
@RunWith(AndroidJUnit4::class)
class BiliAnonymousContractProbe {
    @Test fun probeAnonymousContracts() = runBlocking {
        assumeTrue(InstrumentationRegistry.getArguments().getString("biliLiveProbe") == "true")
        val client = OkHttpClient.Builder().connectTimeout(10, TimeUnit.SECONDS).readTimeout(15, TimeUnit.SECONDS)
            .callTimeout(25, TimeUnit.SECONDS).build()
        val api = BiliContentRepository(BiliGateway(HttpBiliTransport(JsonHttpClient(client))) { BiliCredentials.Empty })
        val results = mutableListOf<JsonObject>()
        suspend fun probe(name: String, action: suspend () -> Map<String, Int>) {
            val result = try {
                val metrics = action()
                buildJsonObject { put("name", name); put("outcome", "ok"); metrics.forEach { (k, v) -> put(k, v) } }
            } catch (error: AppFailure) {
                buildJsonObject {
                    put("name", name); put("outcome", error.javaClass.simpleName)
                    when (error) {
                        is AppFailure.Business -> put("code", error.code)
                        is AppFailure.RiskControl -> put("code", error.code)
                        is AppFailure.Http -> put("http", error.status)
                        else -> Unit
                    }
                }
            }
            results += result
        }
        var bvid = "BV1MBeq6rEz2"
        var detail: VideoDetails? = null
        probe("search") {
            val page = api.search(QuerySpec(keyword = "A-SOUL"), 1)
            page.videos.firstOrNull()?.let { bvid = it.id.value }
            mapOf("count" to page.videos.size)
        }
        probe("detail") {
            val found = api.detail(bvid); detail = found
            mapOf("parts" to found.parts.size)
        }
        detail?.let { video ->
            probe("dash") {
                val streams = api.playback(bvid, video.parts.first().id)
                mapOf("videos" to streams.videos.size, "audios" to streams.audios.size)
            }
            probe("mp4") {
                val streams = api.playback(bvid, video.parts.first().id, mp4 = true)
                mapOf("segments" to streams.segments.size, "actualQuality" to streams.returnedQuality)
            }
            probe("comments") { mapOf("count" to api.comments(video.aid, 1).comments.size) }
            probe("archive") { mapOf("count" to api.archive(video.video.creator.id.toLong(), 1).videos.size) }
        }
        val report = buildJsonObject {
            put("anonymous", true); put("recordedAtMs", System.currentTimeMillis())
            put("scope", "metadata_and_playurl_only_not_media_playback"); put("results", JsonArray(results))
        }
        withContext(Dispatchers.IO) {
            File(ApplicationProvider.getApplicationContext<Context>().cacheDir, "bili-anonymous-kotlin-contract.json").writeText(report.toString())
        }
    }
}
