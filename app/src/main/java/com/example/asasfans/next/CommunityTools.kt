package com.example.asasfans.next

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

internal data class CommunityTool(val label: String, val url: String, val icon: ImageVector, val tone: Int = 0)
internal val communityTools = listOf(
    CommunityTool("录音棚", "https://studio.asoul.us.kg", Icons.Outlined.Headphones),
    CommunityTool("A-SOUL 日历", "https://asoul.love", Icons.Outlined.CalendarMonth, 1),
    CommunityTool("动态站", "https://len5010.top/dynamics/", Icons.Outlined.DynamicFeed, 2),
    CommunityTool("社区导航", "https://nav.asoul.us.kg", Icons.Outlined.Explore, 3),
    CommunityTool("枝网查重", "https://cnki.asoul.us.kg", Icons.Outlined.Fingerprint, 2),
    CommunityTool("枝江小作文", "https://book.asoul.us.kg", Icons.Outlined.EditNote),
    CommunityTool("查重排行榜", "https://cnki.asoul.us.kg/rank", Icons.Outlined.Leaderboard, 3),
    CommunityTool("A-SOUL Wiki", "https://wiki.asoul.us.kg/", Icons.Outlined.MenuBook, 1),
    CommunityTool("录播站", "https://nf.asoul-rec.com", Icons.Outlined.VideoLibrary),
    CommunityTool("BiliTools", "https://www.bilitools.top/t/4/", Icons.Outlined.Build, 1),
    CommunityTool("字幕工具", "https://zimu.live/", Icons.Outlined.Subtitles, 2),
    CommunityTool("AICU", "https://aicu.cc", Icons.Outlined.ManageSearch, 3),
    CommunityTool("VTBs", "https://vtbs.moe", Icons.Outlined.Groups),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityToolsSheet(dismiss: () -> Unit, web: (String) -> Unit) {
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val dark = MaterialTheme.colorScheme.surface.luminance() < .5f
    val tones = if (dark) listOf(DianaPink, Color(0xFFD0BFEA), Color(0xFF9BCDBF), Color(0xFFE6C18A))
        else listOf(DianaDeepRose, Color(0xFF745590), Color(0xFF367565), Color(0xFF936522))
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = sheet, containerColor = MaterialTheme.colorScheme.background) {
        Column(Modifier.widthIn(max = 760.dp).fillMaxWidth().align(Alignment.CenterHorizontally)) {
            PageHeader("工具")
            LazyVerticalGrid(columns = GridCells.Adaptive(104.dp), modifier = Modifier.fillMaxWidth().weight(1f, fill = false).testTag("tools-grid"),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 28.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(communityTools, key = { it.url }) { tool ->
                    val tint = tones[tool.tone]
                    Surface(onClick = { dismiss(); web(tool.url) }, shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.surface) {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Surface(shape = RoundedCornerShape(17.dp), color = tint.copy(alpha = .12f)) {
                                Icon(tool.icon, null, Modifier.padding(14.dp).size(27.dp), tint = tint)
                            }
                            Text(tool.label, style = MaterialTheme.typography.labelLarge, textAlign = TextAlign.Center,
                                minLines = 2, maxLines = 2)
                        }
                    }
                }
            }
        }
    }
}
