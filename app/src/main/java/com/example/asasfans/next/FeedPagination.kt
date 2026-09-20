package com.example.asasfans.next

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.example.asasfans.core.data.FeedSnapshot
import kotlinx.coroutines.flow.distinctUntilChanged

internal data class PagingSignal(val queryKey: String, val cursor: String?, val loadedCount: Int,
    val lastVisible: Int, val totalItems: Int, val enabled: Boolean, val revision: Long? = null)

/** Claims a specific content boundary once, not once per recomposition or loading transition. */
internal class AutoPageGate {
    private data class Boundary(val key: String, val cursor: String?, val count: Int, val revision: Long?)
    private var claimed: Boundary? = null
    fun claim(signal: PagingSignal): Boolean {
        if (!signal.enabled || signal.totalItems <= 0 || signal.lastVisible < 0 || signal.lastVisible < signal.totalItems - 7) return false
        val boundary = Boundary(signal.queryKey, signal.cursor, signal.loadedCount, signal.revision)
        if (claimed == boundary) return false
        claimed = boundary
        return true
    }
}

@Composable
internal fun AutoLoadFeed(grid: LazyGridState, feed: FeedSnapshot, loadMore: () -> Unit) {
    val latest by rememberUpdatedState(feed)
    val action by rememberUpdatedState(loadMore)
    val owner = LocalLifecycleOwner.current
    LaunchedEffect(grid, owner) {
        val gate = AutoPageGate()
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            snapshotFlow {
                val state = latest
                PagingSignal(state.queryKey, state.cursor, state.loadedCount,
                    grid.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1, grid.layoutInfo.totalItemsCount,
                    (state.videos.isNotEmpty() || state.hasCachedMore) && state.updatedAtMs != null && state.hasMore && !state.loading &&
                        state.error == null && (!state.requiresManualLoad || state.hasCachedMore), state.updatedAtMs)
            }.distinctUntilChanged().collect { if (gate.claim(it)) action() }
        }
    }
}

@Composable
internal fun FeedFooter(feed: FeedSnapshot, retry: () -> Unit, continueLoading: () -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
        when {
            feed.appending -> CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
            feed.failedAppend -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(feed.error?.userMessage ?: "加载失败", style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = retry) { Text("重试") }
            }
            !feed.hasMore && feed.videos.isNotEmpty() -> Text("没有更多了", style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            feed.requiresManualLoad && feed.hasMore && !feed.hasCachedMore -> TextButton(onClick = continueLoading) { Text("继续查找") }
        }
    }
}
