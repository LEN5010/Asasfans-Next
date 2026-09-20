package com.example.asasfans.next

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.asasfans.core.model.Video
import java.util.Locale

@Composable
fun MessagePanel(title: String, message: String = "", action: String? = null, onAction: () -> Unit = {}) {
    Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            if (message.isNotBlank()) Text(message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (action != null) TextButton(onClick = onAction) { Text(action) }
        }
    }
}

@Composable
fun EmptyState(title: String, icon: ImageVector = Icons.Outlined.VideoLibrary, action: String? = null, onAction: () -> Unit = {}) {
    Column(Modifier.fillMaxWidth().padding(vertical = 40.dp, horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerHigh) {
            Icon(icon, null, Modifier.padding(18.dp).size(28.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(title, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (action != null) TextButton(onClick = onAction) { Text(action) }
    }
}

@Composable
fun PageHeader(title: String, actions: @Composable RowScope.() -> Unit = {}) {
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).padding(horizontal = 16.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, Modifier.weight(1f), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        actions()
    }
}

@Composable
fun RoundAction(icon: ImageVector, label: String, onClick: () -> Unit, enabled: Boolean = true) {
    Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surface, border = BorderStroke(.5.dp, MaterialTheme.colorScheme.outlineVariant)) {
        IconButton(onClick = onClick, enabled = enabled) { Icon(icon, label, Modifier.size(21.dp)) }
    }
}

@Composable
fun CapsuleTabs(labels: List<String>, selected: String, onSelect: (String) -> Unit, modifier: Modifier = Modifier) {
    Surface(modifier, shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = .55f))) {
        Row(Modifier.horizontalScroll(rememberScrollState()).selectableGroup().padding(4.dp)) {
            labels.forEach { label ->
                val active = selected == label
                val fill by animateColorAsState(if (active) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent, label = "tab")
                Box(Modifier.clip(CircleShape).background(fill).selectable(active, role = Role.Tab, onClick = { onSelect(label) })
                    .heightIn(min = 44.dp).padding(horizontal = 14.dp, vertical = 10.dp), contentAlignment = Alignment.Center) {
                    Text(label, style = MaterialTheme.typography.labelLarge, maxLines = 1,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (active) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
fun videoGridCells(): GridCells {
    val scale = LocalDensity.current.fontScale
    return remember(scale) { object : GridCells {
        override fun Density.calculateCrossAxisCellSizes(availableSize: Int, spacing: Int): List<Int> {
            val count = mediaColumnCount(availableSize.toDp().value, spacing.toDp().value, scale)
            val usable = (availableSize - spacing * (count - 1)).coerceAtLeast(count)
            return List(count) { index -> usable / count + if (index < usable % count) 1 else 0 }
        }
    } }
}

internal fun mediaColumnCount(widthDp: Float, spacingDp: Float = 10f, fontScale: Float = 1f): Int {
    val minimum = (if (widthDp >= 600f) 220f else 160f) * fontScale.coerceAtLeast(1f)
    return ((widthDp + spacingDp) / (minimum + spacingDp)).toInt().coerceIn(1, 6)
}

@Composable
fun CreatorAvatar(name: String, url: String = "", size: Int = 24) {
    Box(Modifier.size(size.dp).clip(CircleShape).background(MaterialTheme.colorScheme.secondaryContainer), contentAlignment = Alignment.Center) {
        Text(name.firstOrNull()?.toString() ?: "U", style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSecondaryContainer)
        if (url.isNotBlank()) AsyncImage(url, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
    }
}

@Composable
fun VideoCard(video: Video, onOpen: () -> Unit, onLater: () -> Unit, laterLabel: String = "加入稍后看", extra: String? = null,
    onInternal: (() -> Unit)? = null, onExternal: (() -> Unit)? = null, onCreator: (() -> Unit)? = null) {
    var menu by remember { mutableStateOf(false) }
    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = .6f))) {
        Column(Modifier.clickable(onClick = onOpen)) {
            Box(Modifier.fillMaxWidth().aspectRatio(16f / 9).background(MaterialTheme.colorScheme.surfaceContainerHigh)) {
                Icon(Icons.Outlined.PlayCircleOutline, null, Modifier.align(Alignment.Center).size(28.dp), tint = MaterialTheme.colorScheme.outline)
                AsyncImage(video.coverUrl, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                Box(Modifier.fillMaxWidth().height(36.dp).align(Alignment.BottomCenter)
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = .7f)))))
                Row(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(horizontal = 8.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    video.views?.let {
                        Icon(Icons.Outlined.PlayArrow, null, Modifier.size(12.dp), tint = Color.White)
                        Text(countText(it), fontSize = 10.sp, color = Color.White)
                    }
                    Spacer(Modifier.weight(1f))
                    if (video.durationMs > 0) Text(timeText(video.durationMs), fontSize = 10.sp, color = Color.White)
                }
            }
            Text(video.title, Modifier.padding(start = 10.dp, end = 10.dp, top = 9.dp), minLines = 2, maxLines = 2,
                overflow = TextOverflow.Ellipsis, fontSize = 14.sp, lineHeight = 19.sp, fontWeight = FontWeight.Medium)
            extra?.let { Text(it, Modifier.padding(start = 10.dp, end = 10.dp, top = 6.dp), maxLines = 1,
                overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelSmall) }
            Row(Modifier.padding(start = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f).heightIn(min = 44.dp)
                    .then(if (onCreator != null) Modifier.clickable(onClickLabel = "查看 UP 主页", onClick = onCreator) else Modifier),
                    verticalAlignment = Alignment.CenterVertically) {
                    CreatorAvatar(video.creator.name, video.creator.avatarUrl, 18)
                    Text(video.creator.name.ifBlank { "UP ${video.creator.id}" }, Modifier.weight(1f).padding(start = 5.dp), maxLines = 1,
                        overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Box {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Outlined.MoreVert, "视频操作", Modifier.size(18.dp)) }
                    DropdownMenu(menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { Text(laterLabel) }, onClick = { menu = false; onLater() }, leadingIcon = { Icon(Icons.Outlined.Schedule, null) })
                        onCreator?.let { action -> DropdownMenuItem(text = { Text("查看 UP 主页") }, onClick = { menu = false; action() }) }
                        onInternal?.let { action -> DropdownMenuItem(text = { Text("App 内播放") }, onClick = { menu = false; action() }) }
                        onExternal?.let { action -> DropdownMenuItem(text = { Text("用 B 站打开") }, onClick = { menu = false; action() }) }
                    }
                }
            }
        }
    }
}

@Composable
fun SectionTitle(title: String, count: Int? = null, action: String? = null, onAction: () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        count?.let { Text(it.toString(), Modifier.padding(start = 8.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        Spacer(Modifier.weight(1f))
        if (action != null) TextButton(onClick = onAction) { Text(action) }
    }
}

@Composable
fun SettingsRow(icon: ImageVector, title: String, value: String? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).heightIn(min = 58.dp).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Icon(icon, null, Modifier.size(21.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(title, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        value?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.outline)
    }
}

fun countText(count: Long): String = when {
    count >= 100_000_000 -> String.format(Locale.ROOT, "%.1f亿", count / 100_000_000.0)
    count >= 10_000 -> String.format(Locale.ROOT, "%.1f万", count / 10_000.0)
    else -> count.toString()
}

fun timeText(ms: Long): String {
    val seconds = ms.coerceAtLeast(0) / 1000
    return if (seconds >= 3600) String.format(Locale.ROOT, "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    else String.format(Locale.ROOT, "%d:%02d", seconds / 60, seconds % 60)
}
