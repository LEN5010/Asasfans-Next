package com.example.asasfans.next

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.asasfans.core.AppContainer
import com.example.asasfans.core.data.FeedSnapshot
import com.example.asasfans.core.model.*
import com.example.asasfans.core.preferences.UserPreferences
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.*

@OptIn(ExperimentalCoroutinesApi::class)
class MainViewModel(val graph: AppContainer, private val saved: SavedStateHandle) : ViewModel() {
    data class Notice(val text: String, val actionLabel: String? = null, val action: (suspend () -> Unit)? = null)
    private val notices = Channel<Notice>(Channel.BUFFERED)
    val messages = notices.receiveAsFlow()
    val startup = graph.startup.state
    val preferences = graph.preferences.state.safeState(UserPreferences())
    val watchLater = graph.library.watchLater.safeState(emptyList())
    val history = graph.library.history.safeState(emptyList())
    val bookmarks = graph.library.bookmarks.safeState(emptyList())
    val collections = graph.library.collections.safeState(emptyList())
    val subscriptions = graph.curation.subscriptions.safeState(emptyList())
    val rules = graph.curation.rules.safeState(emptyList())
    val continuing = graph.library.continueWatching.map { records -> records.mapNotNull { record ->
        graph.library.content(record.contentId)?.let { it to record }
    } }.safeState(emptyList())
    val keyword = saved.getStateFlow("keyword", "")
    val feedMode = saved.getStateFlow("feedMode", "new")
    private val window = saved.getStateFlow("discoverWindow", 40)
    private val todayWindow = saved.getStateFlow("todayWindow", 40)
    // Keep source selection alongside semantic criteria; identical queries from two sources are not the same feed.
    private fun queryFor(word: String, mode: String) = if (mode == "search") QuerySpec(keyword = word.trim()) else QuerySpec(
            order = if (mode == "new") VideoOrder.NEWEST else VideoOrder.POPULAR,
            copyright = if (mode == "clips") 2 else if (mode == "creations") 1 else null,
            days = if (mode == "new") null else 7)
    private val selection = MutableStateFlow(queryFor(keyword.value, saved["feedMode"] ?: "new") to (saved.get<String>("feedMode") ?: "new"))
    val feed = combine(selection, window) { selected, limit -> selected to limit }.flatMapLatest { (selected, limit) ->
        val (query, mode) = selected
        if (mode == "search" && query.keyword.isBlank()) flowOf(FeedSnapshot(hasMore = false))
        else repository(mode).observe(query, limit)
    }.safeState(FeedSnapshot())
    val todayFeed = todayWindow.flatMapLatest { graph.discovery.observe(QuerySpec(), it) }.safeState(FeedSnapshot())
    private var todayStarted = false
    private var discoverStarted = false
    fun ensureTodayLoaded() { if (!todayStarted) { todayStarted = true; refreshToday() } }
    fun ensureDiscoverLoaded() { if (!discoverStarted) { discoverStarted = true; refreshFeed() } }
    private var todayJob: Job? = null
    fun refreshToday() {
        if (todayJob?.isActive != true) todayJob = action { graph.discovery.refresh(QuerySpec()) }
    }
    private var feedJob: Job? = null

    fun setFeed(mode: String, word: String = keyword.value) {
        if (mode !in setOf("new", "clips", "creations", "search")) return
        saved["keyword"] = word.take(256)
        saved["feedMode"] = mode
        val query = queryFor(word.take(256), mode)
        selection.value = query to mode
        saved["discoverWindow"] = 40
        startFeed { if (mode != "search" || query.keyword.isNotBlank()) repository(mode).refresh(query) }
    }
    fun refreshFeed() { val (query, mode) = selection.value; startFeed { if (mode != "search" || query.keyword.isNotBlank()) repository(mode).refresh(query) } }
    fun loadMore() = appendFeed(today = false)
    fun loadMoreToday() = appendFeed(today = true)
    fun retryFeed() { if (feed.value.failedAppend) appendFeed(today = false, retry = true) else refreshFeed() }
    fun retryToday() { if (todayFeed.value.failedAppend) appendFeed(today = true, retry = true) else refreshToday() }
    fun continueFeed() = appendFeed(today = false, retry = true)
    fun continueToday() = appendFeed(today = true, retry = true)

    private fun appendFeed(today: Boolean, retry: Boolean = false) {
        val snapshot = if (today) todayFeed.value else feed.value
        val (query, mode) = if (today) QuerySpec() to "new" else selection.value
        val repo = repository(mode)
        val busy = if (today) todayJob?.isActive == true else feedJob?.isActive == true
        if (busy || snapshot.queryKey != repo.key(query) || snapshot.loading || !snapshot.hasMore || snapshot.updatedAtMs == null) return
        if (!retry && (snapshot.error != null || (snapshot.requiresManualLoad && !snapshot.hasCachedMore))) return
        val windowKey = if (today) "todayWindow" else "discoverWindow"
        val visibleWindow = if (today) todayWindow.value else window.value
        saved[windowKey] = (visibleWindow.toLong() + 40).coerceAtMost(Int.MAX_VALUE.toLong() - 1).toInt()
        if (snapshot.hasCachedMore && !snapshot.failedAppend) return
        val job = action { repo.loadMore(query) }
        if (today) todayJob = job else feedJob = job
    }
    fun addLater(video: Video) = action { graph.library.addWatchLater(video); notify("已加入稍后看") }
    fun removeLater(id: String) = action {
        val video = graph.library.content(id)
        graph.library.removeWatchLater(id)
        notices.send(Notice("已移出稍后看", video?.let { "重新加入" }, video?.let { { graph.library.addWatchLater(it) } }))
    }
    fun action(block: suspend () -> Unit): Job = viewModelScope.launch { runAction(block) }
    private suspend fun runAction(block: suspend () -> Unit) {
        try { block() } catch (error: CancellationException) { throw error }
        catch (error: AppFailure) { notify(error.userMessage) }
        catch (_: IllegalArgumentException) { notify("输入格式不正确，请检查后重试") }
        catch (_: Exception) { notify("操作尚未完成，请检查本地存储后重试") }
    }
    suspend fun notify(message: String) { notices.send(Notice(message)) }
    private fun repository(mode: String) = if (mode == "search") graph.search else graph.discovery
    private fun startFeed(block: suspend () -> Unit) {
        val previous = feedJob
        feedJob = viewModelScope.launch { previous?.cancelAndJoin(); runAction(block) }
    }
    private fun <T> Flow<T>.safeState(initial: T): StateFlow<T> = catch { error ->
        if (error is CancellationException) throw error
        notify("本地资料读取失败，请检查存储空间后重新打开此页")
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), initial)
}
