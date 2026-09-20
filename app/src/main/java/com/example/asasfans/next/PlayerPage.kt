package com.example.asasfans.next

import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material3.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.PlayerView
import com.example.asasfans.player.PlayerPhase
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.isActive

@OptIn(UnstableApi::class)
@kotlin.OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun PlayerPage(vm: PlayerViewModel, main: MainViewModel, back: () -> Unit, external: (String) -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val player by vm.engine.player.collectAsStateWithLifecycle()
    val comments by vm.comments.collectAsStateWithLifecycle()
    val commentError by vm.commentError.collectAsStateWithLifecycle()
    val commentLoading by vm.commentLoading.collectAsStateWithLifecycle()
    val saveError by vm.saveError.collectAsStateWithLifecycle()
    val preferenceError by vm.preferenceError.collectAsStateWithLifecycle()
    val collections by main.collections.collectAsStateWithLifecycle()
    val subscriptions by main.subscriptions.collectAsStateWithLifecycle()
    val video = state.details?.video
    val later by remember(video?.id) { video?.let { vm.graph.library.isWatchLater(it.id.key) } ?: flowOf(false) }.collectAsStateWithLifecycle(false)
    var fullscreen by rememberSaveable { mutableStateOf(false) }
    var bookmark by rememberSaveable { mutableStateOf(false) }
    var bookmarkTitle by rememberSaveable { mutableStateOf("") }
    var bookmarkNote by rememberSaveable { mutableStateOf("") }
    var bookmarkPart by rememberSaveable { mutableLongStateOf(0L) }
    var bookmarkPosition by rememberSaveable { mutableLongStateOf(0L) }
    var collect by rememberSaveable { mutableStateOf(false) }
    var qualityMenu by remember { mutableStateOf(false) }
    var expandedTitle by rememberSaveable { mutableStateOf(false) }
    var speedMenu by remember { mutableStateOf(false) }
    var autoAdvance by rememberSaveable { mutableStateOf(true) }
    val controller = vm.controller
    SideEffect { controller.autoAdvance = autoAdvance }
    val owner = LocalLifecycleOwner.current
    val activity = LocalActivity.current
    BackHandler(fullscreen) { fullscreen = false }
    DisposableEffect(owner, controller) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) controller.setForeground(true)
            if (event == Lifecycle.Event.ON_STOP) controller.setForeground(false)
        }
        owner.lifecycle.addObserver(observer)
        controller.setForeground(owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED))
        onDispose { owner.lifecycle.removeObserver(observer); controller.setForeground(false) }
    }
    LaunchedEffect(owner, controller) {
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (isActive) { controller.tick(); delay(500) }
        }
    }
    DisposableEffect(fullscreen, activity) {
        val window = activity?.window
        val bars = window?.let { WindowCompat.getInsetsController(it, it.decorView) }
        if (fullscreen) {
            bars?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            bars?.hide(WindowInsetsCompat.Type.systemBars())
        } else bars?.show(WindowInsetsCompat.Type.systemBars())
        onDispose { bars?.show(WindowInsetsCompat.Type.systemBars()) }
    }
    fun openExternal() {
        val item = video ?: return
        val number = state.details?.parts?.firstOrNull { it.id == state.partId }?.number ?: 1
        external("https://www.bilibili.com/video/${item.id.value}?p=$number&t=${state.positionMs / 1000}")
    }
    var tab by rememberSaveable { mutableStateOf("简介") }
    var dragging by remember { mutableStateOf(false) }
    var seekValue by remember { mutableFloatStateOf(0f) }
    val mediaPane: @Composable ColumnScope.(Modifier) -> Unit = { frameModifier ->
        Box(frameModifier.fillMaxWidth().background(Color.Black)) {
            AndroidView(factory = { context -> PlayerView(context).apply { useController = false } },
                modifier = Modifier.fillMaxSize(), update = { it.player = player }, onRelease = { it.player = null })
            Box(Modifier.fillMaxSize().pointerInput(controller) {
                detectTapGestures(onDoubleTap = { point -> controller.seek(controller.state.value.positionMs + if (point.x < size.width / 2) -10_000 else 10_000) })
            })
            if (state.phase == PlayerPhase.LOADING || state.phase == PlayerPhase.BUFFERING) CircularProgressIndicator(Modifier.align(Alignment.Center).size(30.dp), color = Color.White, strokeWidth = 2.dp)
            if (state.phase == PlayerPhase.FAILED) Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Outlined.PlayCircleOutline, null, Modifier.size(32.dp), tint = Color.White.copy(alpha = .6f))
                Text("暂时无法播放", color = Color.White, style = MaterialTheme.typography.bodySmall)
            }
        }
        Surface(color = MaterialTheme.colorScheme.surface) {
            Column(Modifier.padding(horizontal = 8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { if (state.phase == PlayerPhase.FAILED) controller.retry() else controller.setPlayIntent(!state.playIntent) }) {
                        Icon(if (state.phase == PlayerPhase.FAILED) Icons.Outlined.Refresh else if (state.playIntent) Icons.Outlined.Pause else Icons.Outlined.PlayArrow,
                            if (state.phase == PlayerPhase.FAILED) "重试播放" else if (state.playIntent) "暂停" else "播放")
                    }
                    Text("${timeText(state.positionMs)} / ${timeText(state.durationMs)}", style = MaterialTheme.typography.labelSmall, modifier = Modifier.weight(1f))
                    Box {
                        TextButton(onClick = { qualityMenu = true }, contentPadding = PaddingValues(horizontal = 8.dp)) {
                            Text(if (state.actualQuality > 0) state.qualities.firstOrNull { it.id == state.actualQuality }?.label ?: "画质" else "自动", style = MaterialTheme.typography.labelSmall)
                        }
                        DropdownMenu(qualityMenu, { qualityMenu = false }) {
                            DropdownMenuItem(text = { Text("自动") }, onClick = { qualityMenu = false; controller.selectQuality(0) })
                            state.qualities.forEach { quality -> DropdownMenuItem(enabled = quality.available, text = { Text(quality.label) },
                                onClick = { qualityMenu = false; controller.selectQuality(quality.id) }) }
                        }
                    }
                    Box {
                        TextButton(onClick = { speedMenu = true }, contentPadding = PaddingValues(horizontal = 6.dp)) { Text("${state.speed}×", style = MaterialTheme.typography.labelSmall) }
                        DropdownMenu(speedMenu, { speedMenu = false }) { listOf(.5f, .75f, 1f, 1.25f, 1.5f, 2f, 3f).forEach { value ->
                            DropdownMenuItem(text = { Text("${value}×") }, onClick = { speedMenu = false; vm.speed(value) })
                        } }
                    }
                    IconButton(onClick = { fullscreen = !fullscreen }) { Icon(if (fullscreen) Icons.Outlined.FullscreenExit else Icons.Outlined.Fullscreen, if (fullscreen) "退出全屏" else "全屏") }
                }
                Slider(value = if (dragging) seekValue else state.positionMs.toFloat(),
                    onValueChange = { dragging = true; seekValue = it },
                    onValueChangeFinished = { controller.seek(seekValue.toLong()); dragging = false },
                    valueRange = 0f..state.durationMs.coerceAtLeast(1).toFloat(), enabled = state.durationMs > 0 && state.phase != PlayerPhase.LOADING,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    thumb = { Box(Modifier.size(12.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary)) },
                    track = { SliderDefaults.Track(it, modifier = Modifier.height(3.dp)) })
            }
        }
    }
    val detailsPane: @Composable () -> Unit = {
        Column {
            CapsuleTabs(listOf("简介", "评论"), tab, { tab = it }, Modifier.padding(horizontal = 12.dp, vertical = 8.dp))
            LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (tab == "简介") {
                    video?.let { item ->
                        item {
                            Text(item.title, style = MaterialTheme.typography.titleMedium, maxLines = if (expandedTitle) Int.MAX_VALUE else 2,
                                overflow = TextOverflow.Ellipsis, modifier = Modifier.clickable { expandedTitle = !expandedTitle })
                        }
                        item { Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            CreatorAvatar(item.creator.name, item.creator.avatarUrl, 32)
                            Text(item.creator.name.ifBlank { "UP ${item.creator.id}" }, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                            val subscribed = subscriptions.any { it.creatorKey == item.creator.key }
                            FilledTonalButton(onClick = { main.action { vm.graph.curation.subscribe(item.creator) } }, enabled = !subscribed,
                                contentPadding = PaddingValues(horizontal = 14.dp)) { Text(if (subscribed) "已订阅" else "订阅") }
                        } }
                        item {
                            Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                                    PlayerAction(if (later) Icons.Outlined.CheckCircle else Icons.Outlined.Schedule, if (later) "已加入" else "稍后看", { if (later) main.removeLater(item.id.key) else main.addLater(item) })
                                    PlayerAction(Icons.Outlined.FolderOpen, "收藏", { collect = true })
                                    PlayerAction(Icons.Outlined.BookmarkBorder, "书签", {
                                        bookmarkPart = state.partId ?: 0; bookmarkPosition = state.positionMs
                                        bookmarkTitle = "${item.title.take(80)} · ${timeText(bookmarkPosition)}"; bookmark = true
                                    }, state.partId != null)
                                }
                            }
                        }
                        state.message?.let { message -> item { MessagePanel("播放失败", message, "重试", controller::retry) } }
                        saveError?.let { item { MessagePanel("进度未保存", it, "重试", vm::retryProgressSave) } }
                        preferenceError?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
                        if (item.description.isNotBlank()) item {
                            Text(item.description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = if (expandedTitle) Int.MAX_VALUE else 3, overflow = TextOverflow.Ellipsis, modifier = Modifier.clickable { expandedTitle = !expandedTitle })
                        }
                    }
                    if (video == null) state.message?.let { message -> item { MessagePanel("加载失败", message, "重试", controller::retry) } }
                    if (state.details?.parts.orEmpty().size > 1) {
                        item { Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("选集", Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                            Text("连播", style = MaterialTheme.typography.labelMedium)
                            Spacer(Modifier.width(8.dp)); Switch(autoAdvance, { autoAdvance = it; controller.autoAdvance = it })
                        } }
                        items(state.details?.parts.orEmpty(), key = { it.id }) { part ->
                            Surface(onClick = { controller.selectPart(part.id) }, shape = RoundedCornerShape(12.dp),
                                color = if (part.id == state.partId) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerLow) {
                                Text("P${part.number}  ${part.title}", Modifier.fillMaxWidth().padding(14.dp), style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                } else {
                    commentError?.let { item { MessagePanel("评论暂不可用", it, "重试") { vm.loadComments() } } }
                    if (!commentLoading && commentError == null && comments?.comments.orEmpty().isEmpty()) item { EmptyState("暂无评论", Icons.Outlined.ChatBubbleOutline) }
                    items(comments?.comments.orEmpty(), key = { it.id }) { comment ->
                        Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                CreatorAvatar(comment.authorName)
                                Text(comment.authorName + if (comment.pinned) " · 置顶" else "", Modifier.weight(1f), style = MaterialTheme.typography.labelMedium)
                                comment.likes?.let { Text("${countText(it)} 赞", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                            }
                            Text(comment.message, style = MaterialTheme.typography.bodyMedium)
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .6f))
                        }
                    }
                    if (commentLoading) item { LinearProgressIndicator(Modifier.fillMaxWidth()) }
                    if (comments?.hasMore == true) item { TextButton(onClick = { vm.loadComments() }, enabled = !commentLoading) { Text("更多评论") } }
                }
            }
        }
    }
    Column(Modifier.fillMaxSize()) {
        if (!fullscreen) Row(Modifier.fillMaxWidth().height(52.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = back) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") }
            Text("视频", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            IconButton(onClick = ::openExternal, enabled = video != null) { Icon(Icons.AutoMirrored.Outlined.OpenInNew, "用 B 站打开") }
        }
        BoxWithConstraints(Modifier.weight(1f)) {
            val wide = maxWidth >= 900.dp || (maxWidth >= 600.dp && maxWidth > maxHeight)
            if (wide && !fullscreen) {
                val frameHeight = playerFrameHeight((maxWidth.value - 12f) * 1.6f / 2.6f, maxHeight.value, LocalDensity.current.fontScale).dp
                Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1.6f)) { mediaPane(Modifier.height(frameHeight)) }
                    Box(Modifier.weight(1f)) { detailsPane() }
                }
            } else Column(Modifier.fillMaxSize()) {
                mediaPane(if (fullscreen) Modifier.weight(1f) else Modifier.aspectRatio(16f / 9))
                if (!fullscreen) Box(Modifier.weight(1f)) { detailsPane() }
            }
        }
    }
    if (bookmark && video != null) AlertDialog(onDismissRequest = { bookmark = false }, title = { Text("保存时间点") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("${timeText(bookmarkPosition)}")
            OutlinedTextField(bookmarkTitle, { bookmarkTitle = it.take(200) }, label = { Text("标题") })
            OutlinedTextField(bookmarkNote, { bookmarkNote = it.take(10_000) }, label = { Text("笔记") })
        }
    }, confirmButton = { TextButton(enabled = bookmarkTitle.isNotBlank(), onClick = {
        main.action { vm.graph.library.addBookmark(video, bookmarkPart, bookmarkPosition, bookmarkTitle, bookmarkNote); bookmark = false; bookmarkNote = ""; main.notify("时间点已保存") }
    }) { Text("保存") } }, dismissButton = { TextButton(onClick = { bookmark = false }) { Text("取消") } })
    if (collect && video != null) AlertDialog(onDismissRequest = { collect = false }, title = { Text("加入收藏夹") }, text = {
        Column {
            if (collections.isEmpty()) Text("暂无收藏夹")
            collections.forEach { collection -> TextButton(onClick = { main.action { vm.graph.library.saveToCollection(collection.id, video); collect = false; main.notify("已加入 ${collection.name}") } }) { Text(collection.name) } }
        }
    }, confirmButton = { TextButton(onClick = { collect = false }) { Text("关闭") } })
}

@Composable
private fun PlayerAction(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, action: () -> Unit, enabled: Boolean = true) {
    Column(Modifier.clickable(enabled = enabled, onClick = action).padding(horizontal = 20.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, Modifier.size(22.dp), tint = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.outline)
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}

internal fun playerFrameHeight(widthDp: Float, heightDp: Float, fontScale: Float = 1f): Float =
    minOf(widthDp * 9f / 16f, (heightDp - 96f * fontScale.coerceAtLeast(1f)).coerceAtLeast(1f))
