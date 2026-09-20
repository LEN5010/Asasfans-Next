package com.example.asasfans.next

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.asasfans.bili.account.AccountStatus

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreatorPage(vm: CreatorViewModel, main: MainViewModel, back: () -> Unit, openVideo: (String) -> Unit,
    external: (String) -> Unit, login: () -> Unit) {
    val profile by vm.profile.collectAsStateWithLifecycle()
    val profileError by vm.profileError.collectAsStateWithLifecycle()
    val profileLoading by vm.profileLoading.collectAsStateWithLifecycle()
    val feed by vm.feed.collectAsStateWithLifecycle()
    val subscriptions by main.subscriptions.collectAsStateWithLifecycle()
    val account by main.graph.account.state.collectAsStateWithLifecycle()
    LaunchedEffect(account.status, account.profile?.mid) {
        if (account.status == AccountStatus.SIGNED_IN && (vm.profileError.value != null || vm.feed.value.error != null)) vm.refresh()
    }
    val subscription = subscriptions.firstOrNull { it.creatorKey == vm.initial.key }
    val creator = profile?.creator ?: vm.initial.copy(
        name = vm.initial.name.ifBlank { subscription?.name.orEmpty().ifBlank { feed.videos.firstOrNull()?.creator?.name.orEmpty() } },
        avatarUrl = vm.initial.avatarUrl.ifBlank { subscription?.avatarUrl.orEmpty() },
    )
    val grid = rememberLazyGridState()
    var expanded by rememberSaveable { mutableStateOf(false) }
    var remove by remember { mutableStateOf(false) }
    var subscribing by remember { mutableStateOf(false) }
    AutoLoadFeed(grid, feed, vm::loadMore)

    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("UP 主页") }, navigationIcon = {
            IconButton(onClick = back) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") }
        }, actions = {
            IconButton(onClick = { external("https://space.bilibili.com/${vm.mid}") }) {
                Icon(Icons.AutoMirrored.Outlined.OpenInNew, "在 B 站打开 UP 主页")
            }
        })
        PullToRefreshBox(isRefreshing = feed.refreshing, onRefresh = vm::refresh, modifier = Modifier.weight(1f)) {
            LazyVerticalGrid(columns = videoGridCells(), state = grid, modifier = Modifier.fillMaxSize().testTag("creator-grid"),
                contentPadding = PaddingValues(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                item(key = "profile", span = { GridItemSpan(maxLineSpan) }) {
                    Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surface) {
                        Column(Modifier.background(Brush.verticalGradient(listOf(MaterialTheme.colorScheme.surfaceContainerLow,
                            MaterialTheme.colorScheme.surface))).padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                CreatorAvatar(creator.name, creator.avatarUrl, 64)
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                    Text(creator.name.ifBlank { "UP ${creator.id}" }, style = MaterialTheme.typography.titleLarge,
                                        maxLines = 2, overflow = TextOverflow.Ellipsis)
                                    Text("UID ${creator.id}", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                            profile?.officialTitle?.takeIf { it.isNotBlank() }?.let {
                                Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                            }
                            profile?.introduction?.takeIf { it.isNotBlank() }?.let {
                                Text(it, Modifier.clickable { expanded = !expanded }, style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = if (expanded) Int.MAX_VALUE else 3,
                                    overflow = TextOverflow.Ellipsis)
                            }
                            FilledTonalButton(onClick = {
                                if (subscription != null) remove = true else {
                                    subscribing = true
                                    main.action { try { main.graph.curation.subscribe(creator) } finally { subscribing = false } }
                                }
                            }, enabled = !subscribing) {
                                Icon(if (subscription == null) Icons.Outlined.Add else Icons.Outlined.Check, null, Modifier.size(18.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(if (subscription == null) "订阅" else "已订阅")
                            }
                        }
                    }
                }
                if (profileLoading && profile == null) item(key = "profile-loading", span = { GridItemSpan(maxLineSpan) }) {
                    LinearProgressIndicator(Modifier.fillMaxWidth())
                }
                profileError?.let { failure -> item(key = "profile-error", span = { GridItemSpan(maxLineSpan) }) {
                    MessagePanel("资料暂不可用", failure.userMessage, "重试", vm::refreshProfile)
                } }
                item(key = "posts", span = { GridItemSpan(maxLineSpan) }) { SectionTitle("投稿视频") }
                if (!feed.failedAppend) feed.error?.let { failure -> item(key = "feed-error", span = { GridItemSpan(maxLineSpan) }) {
                    MessagePanel("投稿暂不可用", failure.userMessage, "重试", vm::retry)
                } }
                if (profileError != null || feed.error != null) item(key = "login", span = { GridItemSpan(maxLineSpan) }) {
                    TextButton(onClick = login) { Text("登录 B 站") }
                }
                if (!feed.loading && feed.error == null && feed.videos.isEmpty() && !feed.hasCachedMore) {
                    item(key = "empty", span = { GridItemSpan(maxLineSpan) }) { EmptyState("暂无可显示的投稿") }
                }
                items(feed.videos, key = { it.id.key }) { video ->
                    val shown = video.copy(creator = creator)
                    VideoCard(shown, { openVideo(video.id.value) }, { main.addLater(shown) })
                }
                item(key = "footer", span = { GridItemSpan(maxLineSpan) }) { FeedFooter(feed, vm::retry, vm::continueLoading) }
            }
        }
    }
    if (remove) AlertDialog(onDismissRequest = { remove = false }, title = { Text("取消订阅？") },
        confirmButton = { TextButton(onClick = {
            remove = false
            main.action { main.graph.curation.unsubscribe(creator.key) }
        }) { Text("取消订阅") } }, dismissButton = { TextButton(onClick = { remove = false }) { Text("保留") } })
}
