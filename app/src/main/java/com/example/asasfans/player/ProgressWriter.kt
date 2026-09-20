package com.example.asasfans.player

import com.example.asasfans.core.data.LibraryRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Application-owned writer survives screen disposal. Coalesce per part, not across parts. */
class ProgressWriter(scope: CoroutineScope, private val save: suspend (ProgressRecord) -> Unit) {
    constructor(scope: CoroutineScope, library: LibraryRepository) : this(scope, { record ->
        library.recordProgress(record.video, record.partId, record.positionMs, record.durationMs, record.completed)
    })
    private val pending = linkedMapOf<Pair<String, Long>, ProgressRecord>()
    private val signal = Channel<Unit>(Channel.CONFLATED)
    private val mutableError = MutableStateFlow<String?>(null)
    val error = mutableError.asStateFlow()
    init {
        scope.launch {
            for (ignored in signal) {
                val batch = synchronized(pending) { pending.toMap() }
                for ((key, record) in batch) {
                    try {
                        save(record)
                        synchronized(pending) { if (pending[key] === record) pending.remove(key) }
                        mutableError.value = null
                    } catch (error: CancellationException) { throw error }
                    catch (_: Exception) { mutableError.value = "播放进度尚未保存，请检查存储空间后重试"; break }
                }
            }
        }
    }
    fun submit(record: ProgressRecord) {
        synchronized(pending) { pending[record.video.id.key to record.partId] = record }
        signal.trySend(Unit)
    }
    fun retry() { signal.trySend(Unit) }
}
