package com.example.asasfans.next

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.asasfans.bili.content.CommentPage
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.player.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

class PlayerViewModel(
    app: NextApplication, bvid: String, part: Long?, position: Long?, saved: SavedStateHandle,
) : ViewModel() {
    val graph = app.container
    val engine = Media3PlaybackEngine(app, graph.biliMedia)
    val controller = PlayerController(viewModelScope, engine, graph.bili::detail, graph.bili::playback,
        readProgress = { id, partId ->
            try {
                (if (partId == null) graph.library.latestProgress(id) else graph.library.progress(id, partId))?.let {
                    SavedPosition(it.partId, it.positionMs, it.completed)
                }
            } catch (error: CancellationException) { throw error }
            catch (_: Exception) { throw AppFailure.LocalStorage() }
        }, saveProgress = app.progressWriter::submit)
    val state = controller.state
    val saveError = app.progressWriter.error
    private val progressWriter = app.progressWriter
    private val mutablePreferenceError = MutableStateFlow<String?>(null)
    val preferenceError = mutablePreferenceError.asStateFlow()
    private val initialPart = saved.get<Long>("selectedPart") ?: part
    private val initialPosition = saved.get<Long>("position") ?: position
    private val initialPlay = saved.get<Boolean>("playIntent") ?: true
    private val mutableComments = MutableStateFlow<CommentPage?>(null)
    val comments = mutableComments.asStateFlow()
    private val mutableCommentError = MutableStateFlow<String?>(null)
    val commentError = mutableCommentError.asStateFlow()
    private val mutableCommentLoading = MutableStateFlow(false)
    val commentLoading = mutableCommentLoading.asStateFlow()
    init {
        viewModelScope.launch {
            try { controller.setSpeed(graph.preferences.state.first().playbackSpeed) }
            catch (error: CancellationException) { throw error }
            catch (_: Exception) { mutablePreferenceError.value = "播放偏好读取失败，本次使用默认倍速" }
            controller.open(bvid, initialPart, initialPosition, initialPlay)
        }
        viewModelScope.launch {
            state.collect {
                it.partId?.let { id -> saved["selectedPart"] = id; saved["position"] = it.positionMs }
                saved["playIntent"] = it.playIntent
            }
        }
        viewModelScope.launch {
            state.map { it.details?.aid }.distinctUntilChanged().filterNotNull().collect { loadComments(reset = true) }
        }
    }
    fun speed(value: Float) {
        controller.setSpeed(value)
        viewModelScope.launch {
            try { graph.preferences.setPlaybackSpeed(value); mutablePreferenceError.value = null }
            catch (error: CancellationException) { throw error }
            catch (_: Exception) { mutablePreferenceError.value = "本次倍速已生效，但偏好保存失败" }
        }
    }
    fun retryProgressSave() = progressWriter.retry()
    fun loadComments(reset: Boolean = false) {
        if (mutableCommentLoading.value) return
        val aid = state.value.details?.aid ?: return
        val previous = if (reset) null else comments.value
        if (previous?.hasMore == false) return
        mutableCommentLoading.value = true
        mutableCommentError.value = null
        viewModelScope.launch {
            try {
                val next = graph.bili.comments(aid, (previous?.page ?: 0) + 1)
                mutableComments.value = next.copy(comments = (previous?.comments.orEmpty() + next.comments).distinctBy { it.id })
            } catch (error: CancellationException) { throw error }
            catch (error: AppFailure) { mutableCommentError.value = error.userMessage }
            finally { mutableCommentLoading.value = false }
        }
    }
    override fun onCleared() { controller.close() }
}
