package com.example.asasfans.core.data

import android.database.sqlite.SQLiteException
import androidx.room.withTransaction
import com.example.asasfans.core.database.*
import com.example.asasfans.core.model.*
import com.example.asasfans.core.network.VideoPage
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.sync.Mutex
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

data class FeedSnapshot(
    val videos: List<Video> = emptyList(),
    val loading: Boolean = false,
    val hasMore: Boolean = true,
    val updatedAtMs: Long? = null,
    val error: AppFailure? = null,
    val filteredCount: Int = 0,
    val tagsIncomplete: Boolean = false,
)

/** Atomic refresh, success-only cursors and bounded refill. Source ordering is preserved. */
class FeedRepository(
    private val database: AsasDatabase,
    private val sourceName: String,
    private val loadPage: suspend (QuerySpec, Int) -> VideoPage,
    private val awaitReady: suspend () -> Unit,
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    private data class LoadState(val loading: Boolean = false, val error: AppFailure? = null)
    private val locks = ConcurrentHashMap<String, Mutex>()
    private val loads = ConcurrentHashMap<String, MutableStateFlow<LoadState>>()

    fun observe(query: QuerySpec, limit: Int = 100): Flow<FeedSnapshot> {
        require(limit in 1..1000)
        val key = key(query)
        return combine(database.feeds().entries(key, limit), database.feeds().observeSyncState(key),
            database.assets().rules(), loadState(key)) { entries, sync, rules, loading ->
            val decisions = entries.map { it.toVideo() }.map { video -> video to
                ContentRuleEvaluator.evaluate(video, rules.toRules(), nowMs()) }
            FeedSnapshot(
                decisions.filterNot { it.second.blocked }.map { it.first }, loading.loading,
                sync?.exhausted != true, sync?.lastSuccessMs, loading.error,
                decisions.count { it.second.blocked }, decisions.any { it.second.tagsUnknown },
            )
        }
    }

    suspend fun refresh(query: QuerySpec) = load(query, reset = true)
    suspend fun loadMore(query: QuerySpec) = load(query, reset = false)

    private suspend fun load(query: QuerySpec, reset: Boolean) {
        awaitReady()
        val key = key(query)
        val lock = locks.getOrPut(key) { Mutex() }
        // Duplicate scroll/refresh gestures must not queue an unbounded series of loads.
        if (!lock.tryLock()) return
        try {
            val previous = database.feeds().syncState(key)
            if (!reset && previous?.exhausted == true) return
            val state = loadState(key)
            state.value = LoadState(loading = true)
            try {
                var page = if (reset) 1 else previous?.cursor?.toIntOrNull() ?: 1
                val existing = if (reset) emptySet() else database.feeds().contentIds(key).toSet()
                val loaded = linkedMapOf<String, Video>()
                val rules = database.assets().allRules().toRules()
                var hasMore: Boolean
                var scans = 0
                do {
                    val response = loadPage(query, page)
                    if (response.page != page) throw AppFailure.InvalidResponse()
                    response.videos.filterNot { it.id.key in existing }.forEach { loaded.putIfAbsent(it.id.key, it) }
                    page++
                    scans++
                    hasMore = response.hasMore
                } while (hasMore && scans < MAX_SCAN_PAGES &&
                    loaded.values.count { !ContentRuleEvaluator.evaluate(it, rules, nowMs()).blocked } < MIN_VISIBLE_BATCH)

                database.withTransaction {
                    val now = nowMs()
                    val offset = if (reset) 0 else database.feeds().count(key)
                    if (reset) database.feeds().clearFeed(key)
                    loaded.values.forEach { video ->
                        val old = database.assets().content(video.id.key)
                        val next = ContentEntity.from(video, now)
                        database.assets().putContent(next.copy(tagsJson = next.tagsJson ?: old?.tagsJson,
                            views = next.views ?: old?.views, likes = next.likes ?: old?.likes))
                    }
                    database.feeds().putEntries(loaded.values.mapIndexed { index, video ->
                        FeedEntryEntity(key, video.id.key, video.publishedAtMs, now, offset + index)
                    })
                    database.feeds().putSyncState(SyncStateEntity(key, page.toString(), now, exhausted = !hasMore))
                }
                state.value = LoadState()
            } catch (error: CancellationException) {
                state.value = LoadState()
                throw error
            } catch (error: AppFailure) {
                // Existing rows and cursor remain intact. UI shows this separately from empty data.
                state.value = LoadState(error = error)
            } catch (error: SQLiteException) {
                state.value = LoadState(error = AppFailure.LocalStorage())
            } finally {
                if (state.value.loading) state.value = state.value.copy(loading = false)
            }
        } finally { lock.unlock() }
    }

    internal fun key(query: QuerySpec): String = "$sourceName:" + MessageDigest.getInstance("SHA-256")
        .digest(Json.encodeToString(query).toByteArray()).joinToString("") { "%02x".format(it) }

    private fun loadState(key: String) = loads.getOrPut(key) { MutableStateFlow(LoadState()) }
    private fun List<RuleEntity>.toRules() = map { ContentRule(it.id, RuleKind.valueOf(it.kind), it.value, it.enabled, it.expiresAtMs) }

    companion object {
        private const val MAX_SCAN_PAGES = 5
        private const val MIN_VISIBLE_BATCH = 10
    }
}
