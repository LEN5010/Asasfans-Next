package com.example.asasfans.next

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.asasfans.core.model.Creator
import com.example.asasfans.core.model.RuleKind
import com.example.asasfans.core.database.RuleEntity

val communityTools = listOf(
    "录音棚" to "https://studio.asoul.us.kg", "A-SOUL 日历" to "https://asoul.love",
    "动态站" to "https://len5010.top/dynamics/", "枝网查重" to "https://cnki.asoul.us.kg",
    "导航站" to "https://nav.asoul.us.kg", "枝江小作文" to "https://book.asoul.us.kg",
    "查重排行榜" to "https://cnki.asoul.us.kg/rank", "A-SOUL Wiki" to "https://wiki.asoul.us.kg/",
    "录播站" to "https://nf.asoul-rec.com", "BiliTools" to "https://www.bilitools.top/t/4/",
    "字幕工具" to "https://zimu.live/", "AICU" to "https://aicu.cc", "VTBs" to "https://vtbs.moe",
)


@Composable
fun TodayPage(vm: MainViewModel, onOpen: (String, Long?, Long?) -> Unit, discover: () -> Unit, library: () -> Unit, web: (String) -> Unit) {
    val continuing by vm.continuing.collectAsStateWithLifecycle()
    val later by vm.watchLater.collectAsStateWithLifecycle()
    val feed by vm.todayFeed.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.refreshToday() }
    var tools by rememberSaveable { mutableStateOf(false) }
    Column {
        PageHeader("Asasfans") { RoundAction(Icons.Outlined.Explore, "发现视频", discover) }
        LazyVerticalGrid(columns = videoGridCells(), contentPadding = PaddingValues(12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    listOf(Icons.Outlined.Headphones to "录音棚", Icons.Outlined.CalendarMonth to "日历", Icons.Outlined.GridView to "工具").forEachIndexed { index, (icon, title) ->
                        Card(onClick = { if (index == 2) tools = true else web(communityTools[index].second) }, Modifier.weight(1f),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow), shape = RoundedCornerShape(16.dp)) {
                            Row(Modifier.fillMaxWidth().padding(vertical = 18.dp), verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
                                Icon(icon, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
                                Text(title, style = MaterialTheme.typography.labelLarge)
                            }
                        }
                    }
                }
            }
            if (continuing.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) { SectionTitle("继续观看") }
                items(continuing.take(2), key = { it.first.id.key + ":" + it.second.partId }) { (video, progress) ->
                    VideoCard(video, { onOpen(video.id.value, progress.partId, progress.positionMs) }, { vm.addLater(video) },
                        extra = "${timeText(progress.positionMs)} / ${timeText(progress.durationMs)}")
                }
            }
            item(span = { GridItemSpan(maxLineSpan) }) { SectionTitle("最新视频", action = "更多", onAction = discover) }
            if (feed.loading && feed.videos.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { LinearProgressIndicator(Modifier.fillMaxWidth()) }
            feed.error?.let { failure -> item(span = { GridItemSpan(maxLineSpan) }) { MessagePanel("加载失败", failure.userMessage, "重试", vm::refreshToday) } }
            if (!feed.loading && feed.videos.isEmpty() && feed.error == null) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState("暂无视频", action = "刷新", onAction = vm::refreshToday) }
            items(feed.videos.take(6), key = { "new:${it.id.key}" }) { video ->
                VideoCard(video, { onOpen(video.id.value, null, null) }, { vm.addLater(video) })
            }
            if (later.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) { SectionTitle("稍后看", later.size, "全部", library) }
                items(later.take(4), key = { "later:${it.id}" }) { row ->
                    VideoCard(row.toVideo(), { onOpen(row.sourceId, null, null) }, { vm.removeLater(row.id) }, "移出稍后看")
                }
            }

        }
    }
    if (tools) CommunityToolsSheet({ tools = false }, web)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverPage(vm: MainViewModel, open: (String) -> Unit, internal: (String) -> Unit, external: (String) -> Unit, web: (String) -> Unit, rules: () -> Unit) {
    val feed by vm.feed.collectAsStateWithLifecycle()
    val keyword by vm.keyword.collectAsStateWithLifecycle()
    val mode by vm.feedMode.collectAsStateWithLifecycle()
    var search by rememberSaveable { mutableStateOf(false) }
    var tools by rememberSaveable { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    var loaded by rememberSaveable { mutableStateOf(false) }
    val grid = rememberLazyGridState()
    val categories = listOf("new" to "最新", "creations" to "二创", "clips" to "切片")
    LaunchedEffect(Unit) { if (!loaded) { loaded = true; vm.refreshFeed() } }
    var displayedQuery by rememberSaveable { mutableStateOf("$mode:$keyword") }
    LaunchedEffect(mode, keyword) {
        val nextQuery = "$mode:$keyword"
        if (displayedQuery != nextQuery) { grid.scrollToItem(0); displayedQuery = nextQuery }
    }
    Column {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CapsuleTabs(categories.map { it.second }, categories.firstOrNull { it.first == mode }?.second.orEmpty(),
                { label -> vm.setFeed(categories.first { it.second == label }.first) }, Modifier.weight(1f))
            RoundAction(Icons.Outlined.Search, "搜索视频", { search = true })
            Box {
                RoundAction(Icons.Outlined.MoreVert, "发现选项", { menu = true })
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem(text = { Text("刷新") }, leadingIcon = { Icon(Icons.Outlined.Refresh, null) }, onClick = { menu = false; vm.refreshFeed() })
                    DropdownMenuItem(text = { Text("内容规则") }, leadingIcon = { Icon(Icons.Outlined.Tune, null) }, onClick = { menu = false; rules() })
                    DropdownMenuItem(text = { Text("社区工具") }, leadingIcon = { Icon(Icons.Outlined.GridView, null) }, onClick = { menu = false; tools = true })
                }
            }
        }
        if (mode == "search") Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(keyword, Modifier.weight(1f), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            IconButton(onClick = { vm.setFeed("new") }) { Icon(Icons.Outlined.Close, "清除搜索") }
        }
        PullToRefreshBox(isRefreshing = feed.loading, onRefresh = vm::refreshFeed, modifier = Modifier.weight(1f)) {
            LazyVerticalGrid(columns = videoGridCells(), state = grid, modifier = Modifier.fillMaxSize().testTag("video-grid"),
                contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 2.dp, bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                feed.error?.let { failure -> item(span = { GridItemSpan(maxLineSpan) }) { MessagePanel("加载失败", failure.userMessage, "重试", vm::refreshFeed) } }
                if (!feed.loading && feed.videos.isEmpty() && feed.error == null) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState("暂无视频", action = "重新加载", onAction = vm::refreshFeed) }
                items(feed.videos, key = { it.id.key }) { video ->
                    VideoCard(video, { open(video.id.value) }, { vm.addLater(video) },
                        onInternal = { internal(video.id.value) }, onExternal = { external("https://www.bilibili.com/video/${video.id.value}") })
                }
                if (feed.hasMore && feed.videos.isNotEmpty()) item(span = { GridItemSpan(maxLineSpan) }) {
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        TextButton(onClick = vm::loadMore, enabled = !feed.loading) { Text(if (feed.loading) "加载中…" else "加载更多") }
                    }
                }
            }
        }
    }
    if (search) SearchDialog("搜索视频", keyword, { search = false }) { vm.setFeed("search", it); search = false }
    if (tools) CommunityToolsSheet({ tools = false }, web)
}

@Composable
fun SearchDialog(title: String, initial: String, dismiss: () -> Unit, submit: (String) -> Unit) {
    var text by rememberSaveable { mutableStateOf(initial) }
    val focus = remember { FocusRequester() }
    var focused by remember { mutableStateOf(false) }
    fun search() { if (text.isNotBlank()) submit(text.trim()) }
    AlertDialog(onDismissRequest = dismiss, title = { Text(title) }, text = {
        OutlinedTextField(text, { text = it.take(256) }, Modifier.fillMaxWidth().focusRequester(focus).onGloballyPositioned {
            if (!focused) { focused = true; focus.requestFocus() }
        }, singleLine = true,
            placeholder = { Text("关键词") }, leadingIcon = { Icon(Icons.Outlined.Search, null) },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search), keyboardActions = KeyboardActions(onSearch = { search() }))
    }, confirmButton = { TextButton(onClick = ::search, enabled = text.isNotBlank()) { Text("搜索") } },
        dismissButton = { TextButton(onClick = dismiss) { Text("取消") } })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityToolsSheet(dismiss: () -> Unit, web: (String) -> Unit) {
    ModalBottomSheet(onDismissRequest = dismiss) {
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp)) {
            item { SectionTitle("社区工具") }
            items(communityTools) { (label, url) -> SettingsRow(Icons.Outlined.Language, label, onClick = { dismiss(); web(url) }) }
        }
    }
}

@Composable
fun FollowingPage(vm: MainViewModel) {
    val subscriptions by vm.subscriptions.collectAsStateWithLifecycle()
    var uid by rememberSaveable { mutableStateOf("") }
    var adding by rememberSaveable { mutableStateOf(false) }
    var removing by remember { mutableStateOf<String?>(null) }
    Column {
        PageHeader("关注") { RoundAction(Icons.Outlined.Add, "添加订阅", { adding = true }) }
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { SectionTitle("订阅的 UP", subscriptions.size) }
            if (subscriptions.isEmpty()) item { EmptyState("暂无订阅", Icons.Outlined.Subscriptions, "添加订阅", { adding = true }) }
            items(subscriptions, key = { it.creatorKey }) { subscription ->
                Surface(shape = RoundedCornerShape(16.dp)) {
                    Row(Modifier.fillMaxWidth().padding(start = 14.dp, top = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        CreatorAvatar(subscription.name, subscription.avatarUrl, size = 40)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(subscription.name.ifBlank { "UP ${subscription.creatorId}" }, style = MaterialTheme.typography.titleSmall)
                            Text("UID ${subscription.creatorId}" + subscription.groupName.takeIf { it.isNotBlank() }?.let { " · $it" }.orEmpty(),
                                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            if (subscription.note.isNotBlank()) Text(subscription.note, style = MaterialTheme.typography.bodySmall)
                        }
                        IconButton(onClick = { removing = subscription.creatorKey }) { Icon(Icons.Outlined.PersonRemove, "取消订阅", Modifier.size(20.dp)) }
                    }
                }
            }
        }
    }
    if (adding) AlertDialog(onDismissRequest = { adding = false }, title = { Text("添加订阅") }, text = {
        OutlinedTextField(uid, { uid = it.take(20) }, label = { Text("UP 的数字 UID") }, singleLine = true)
    }, confirmButton = { TextButton(onClick = { vm.action { vm.graph.curation.subscribe(Creator(id = uid.trim())); uid = ""; adding = false } }, enabled = uid.isNotBlank()) { Text("添加") } },
        dismissButton = { TextButton(onClick = { adding = false }) { Text("取消") } })
    removing?.let { key -> AlertDialog(onDismissRequest = { removing = null }, title = { Text("取消订阅？") },
        confirmButton = { TextButton(onClick = { vm.action { vm.graph.curation.unsubscribe(key) }; removing = null }) { Text("取消订阅") } },
        dismissButton = { TextButton(onClick = { removing = null }) { Text("保留") } }) }
}

private fun ruleLabel(kind: String) = when (kind) { "WORD" -> "关键词"; "TAG" -> "Tag"; "CREATOR" -> "UP"; "VIDEO" -> "视频"; else -> kind }

@Composable
fun RulesPage(vm: MainViewModel) {
    val rules by vm.rules.collectAsStateWithLifecycle()
    var kind by rememberSaveable { mutableStateOf(RuleKind.WORD) }
    var value by rememberSaveable { mutableStateOf("") }
    var adding by rememberSaveable { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<RuleEntity?>(null) }
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { SectionTitle("屏蔽规则", rules.size, "添加", { adding = true }) }
        if (rules.isEmpty()) item { EmptyState("暂无屏蔽规则", Icons.Outlined.FilterAltOff) }
        items(rules, key = { it.id }) { rule -> Surface(shape = RoundedCornerShape(14.dp)) { Row(Modifier.padding(start = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(rule.value, style = MaterialTheme.typography.bodyMedium); Text(ruleLabel(rule.kind), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            Switch(rule.enabled, { vm.action { vm.graph.curation.toggleRule(rule) } })
            IconButton(onClick = { deleting = rule }) { Icon(Icons.Outlined.DeleteOutline, "删除规则", Modifier.size(20.dp)) }
        } } }
    }
    if (adding) AlertDialog(onDismissRequest = { adding = false }, title = { Text("添加屏蔽规则") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CapsuleTabs(RuleKind.entries.map { ruleLabel(it.name) }, ruleLabel(kind.name), { label -> kind = RuleKind.entries.first { ruleLabel(it.name) == label } })
            OutlinedTextField(value, { value = it.take(256) }, Modifier.fillMaxWidth(), label = { Text("规则内容") }, singleLine = true)
        }
    }, confirmButton = { TextButton(onClick = { vm.action { vm.graph.curation.addRule(kind, value); value = ""; adding = false } }, enabled = value.isNotBlank()) { Text("添加") } },
        dismissButton = { TextButton(onClick = { adding = false }) { Text("取消") } })
    deleting?.let { rule -> AlertDialog(onDismissRequest = { deleting = null }, title = { Text("删除屏蔽规则？") },
        text = { Text(rule.value) }, confirmButton = { TextButton(onClick = { vm.action { vm.graph.curation.removeRule(rule.id) }; deleting = null }) { Text("删除") } },
        dismissButton = { TextButton(onClick = { deleting = null }) { Text("保留") } }) }
}
