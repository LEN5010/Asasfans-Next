package com.example.asasfans.next

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.asasfans.bili.content.CreatorProfile
import com.example.asasfans.core.AppContainer
import com.example.asasfans.core.data.FeedSnapshot
import com.example.asasfans.core.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

@OptIn(ExperimentalCoroutinesApi::class)
class CreatorViewModel(val graph: AppContainer, val initial: Creator, private val saved: SavedStateHandle) : ViewModel() {
    val mid = initial.id.toLong()
    private val query = QuerySpec(creatorId = initial.id)
    private val window = saved.getStateFlow("creatorWindow", 40)
    private val mutableProfile = MutableStateFlow<CreatorProfile?>(null)
    private val mutableProfileError = MutableStateFlow<AppFailure?>(null)
    private val mutableProfileLoading = MutableStateFlow(false)
    val profile = mutableProfile.asStateFlow()
    val profileError = mutableProfileError.asStateFlow()
    val profileLoading = mutableProfileLoading.asStateFlow()
    private val feedFailure = MutableStateFlow<Pair<AppFailure, Boolean>?>(null)
    private val observerRevision = MutableStateFlow(0)
    val feed = combine(window, observerRevision) { limit, _ -> limit }.flatMapLatest { limit ->
        graph.creatorVideos.observe(query, limit).catch { error ->
            if (error is CancellationException) throw error
            emit(FeedSnapshot(queryKey = graph.creatorVideos.key(query), error = AppFailure.LocalStorage()))
        }
    }.combine(feedFailure) { snapshot, failure ->
        if (failure == null) snapshot else snapshot.copy(error = failure.first, failedAppend = failure.second)
    }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FeedSnapshot())
    private var profileJob: Job? = null
    private var feedJob: Job? = null

    init { require(mid > 0); refresh() }

    fun refresh() {
        refreshProfile()
        if (feedJob?.isActive != true) {
            observerRevision.value++
            feedJob = requestFeed(append = false)
        }
    }

    fun refreshProfile() {
        if (profileJob?.isActive == true) return
        profileJob = viewModelScope.launch {
            mutableProfileLoading.value = true
            mutableProfileError.value = null
            try { mutableProfile.value = graph.bili.creator(mid) }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (failure: AppFailure) { mutableProfileError.value = failure }
            catch (_: Exception) { mutableProfileError.value = AppFailure.InvalidResponse() }
            finally { mutableProfileLoading.value = false }
        }
    }

    fun loadMore() = append(false)
    fun retry() { if (feed.value.failedAppend) append(true) else refresh() }
    fun continueLoading() = append(true)

    private fun append(manual: Boolean) {
        val snapshot = feed.value
        if (feedJob?.isActive == true || snapshot.loading || !snapshot.hasMore || snapshot.updatedAtMs == null) return
        if (!manual && (snapshot.error != null || (snapshot.requiresManualLoad && !snapshot.hasCachedMore))) return
        saved["creatorWindow"] = (window.value.toLong() + 40).coerceAtMost(Int.MAX_VALUE.toLong() - 1).toInt()
        if (snapshot.hasCachedMore && !snapshot.failedAppend) return
        feedJob = requestFeed(append = true)
    }

    private fun requestFeed(append: Boolean) = viewModelScope.launch {
        feedFailure.value = null
        try {
            if (append) graph.creatorVideos.loadMore(query) else graph.creatorVideos.refresh(query)
        } catch (cancelled: CancellationException) { throw cancelled }
        catch (failure: AppFailure) { feedFailure.value = failure to append }
        catch (_: Exception) { feedFailure.value = AppFailure.LocalStorage() to append }
    }
}
