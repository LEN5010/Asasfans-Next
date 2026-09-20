package com.example.asasfans.next

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun LibraryPage(vm: MainViewModel, open: (String, Long?, Long?) -> Unit) {
    val later by vm.watchLater.collectAsStateWithLifecycle()
    val history by vm.history.collectAsStateWithLifecycle()
    val bookmarks by vm.bookmarks.collectAsStateWithLifecycle()
    val collections by vm.collections.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf("稍后看") }
    var collectionId by rememberSaveable { mutableStateOf<String?>(null) }
    var newCollection by rememberSaveable { mutableStateOf(false) }
    var search by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var query by rememberSaveable { mutableStateOf("") }
    val results by remember(query) { vm.graph.library.search(query) }.collectAsStateWithLifecycle(emptyList())
    val contents by remember(collectionId) { vm.graph.library.collectionContents(collectionId.orEmpty()) }.collectAsStateWithLifecycle(emptyList())
    val videos = when { query.isNotBlank() -> results; collectionId != null -> contents; tab == "稍后看" -> later; tab == "历史" -> history; else -> emptyList() }
    val grid = rememberLazyGridState()
    var displayedTab by rememberSaveable { mutableStateOf(tab) }
    var displayedCollection by rememberSaveable { mutableStateOf(collectionId) }
    var displayedQuery by rememberSaveable { mutableStateOf(query) }
    LaunchedEffect(tab, collectionId, query) {
        if (displayedTab != tab || displayedCollection != collectionId || displayedQuery != query) {
            grid.scrollToItem(0)
            displayedTab = tab; displayedCollection = collectionId; displayedQuery = query
        }
    }
    Column {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CapsuleTabs(listOf("稍后看", "收藏夹", "历史", "书签"), tab, { tab = it; query = ""; collectionId = null }, Modifier.weight(1f))
            RoundAction(Icons.Outlined.Search, "搜索资料库", { search = true })
        }
        LazyVerticalGrid(columns = videoGridCells(), state = grid, modifier = Modifier.fillMaxSize().testTag("library-grid"), contentPadding = PaddingValues(12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (query.isNotBlank()) item(span = { GridItemSpan(maxLineSpan) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(query, Modifier.weight(1f), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    IconButton(onClick = { query = "" }) { Icon(Icons.Outlined.Close, "清除搜索") }
                }
            }
            if (collectionId != null) item(span = { GridItemSpan(maxLineSpan) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { collectionId = null }) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回收藏夹列表") }
                    Text(collections.firstOrNull { it.id == collectionId }?.name ?: "收藏夹", style = MaterialTheme.typography.titleSmall)
                }
            }
            if (tab == "收藏夹" && query.isBlank() && collectionId == null) {
                item(span = { GridItemSpan(maxLineSpan) }) { SectionTitle("收藏夹", collections.size, "新建收藏夹", { newCollection = true }) }
                if (collections.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState("暂无收藏夹", Icons.Outlined.FolderOpen) }
                items(collections, key = { it.id }) { collection ->
                    Card(onClick = { collectionId = collection.id }, shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow)) {
                        Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
                            Icon(Icons.Outlined.FolderOpen, null, Modifier.size(32.dp), tint = MaterialTheme.colorScheme.primary)
                            Text(collection.name, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            } else if (tab == "书签" && query.isBlank()) {
                if (bookmarks.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState("暂无书签", Icons.Outlined.BookmarkBorder) }
                items(bookmarks, key = { it.id }, span = { GridItemSpan(maxLineSpan) }) { mark ->
                    Card(onClick = { open(mark.contentId.substringAfter(':'), mark.partId, mark.positionMs) }, shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            Surface(shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.secondaryContainer) {
                                Text(timeText(mark.positionMs), Modifier.padding(8.dp), style = MaterialTheme.typography.labelMedium)
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(mark.title, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                if (mark.note.isNotBlank()) Text(mark.note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            } else {
                if (videos.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState(if (query.isBlank()) "暂无视频" else "未找到相关内容") }
                items(videos, key = { it.id }) { row ->
                    VideoCard(row.toVideo(), { open(row.sourceId, null, null) }, {
                        if (tab == "稍后看" && query.isBlank() && collectionId == null) vm.removeLater(row.id) else vm.addLater(row.toVideo())
                    }, if (tab == "稍后看" && query.isBlank() && collectionId == null) "移出稍后看" else "加入稍后看")
                }
            }
        }
    }
    if (search) SearchDialog("搜索资料库", query, { search = false }) { query = it; collectionId = null; search = false }
    if (newCollection) AlertDialog(onDismissRequest = { newCollection = false }, title = { Text("新建收藏夹") },
        text = { OutlinedTextField(name, { name = it.take(100) }, label = { Text("名称") }) },
        confirmButton = { TextButton(onClick = { vm.action { vm.graph.library.createCollection(name); name = ""; newCollection = false } }, enabled = name.isNotBlank()) { Text("创建") } },
        dismissButton = { TextButton(onClick = { newCollection = false }) { Text("取消") } })
}
