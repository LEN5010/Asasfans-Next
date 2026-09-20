package com.example.asasfans.next

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

internal data class MainSection(val path: String, val label: String, val icon: ImageVector)
internal val sections = listOf(
    MainSection("today", "今日", Icons.Outlined.Home),
    MainSection("discover", "发现", Icons.Outlined.Explore),
    MainSection("following", "关注", Icons.Outlined.Subscriptions),
    MainSection("library", "资料库", Icons.Outlined.VideoLibrary),
    MainSection("mine", "我的", Icons.Outlined.Person),
)

@Composable
internal fun CompactNavigation(route: String?, navigate: (String) -> Unit) {
    Surface(Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().testTag("bottom-navigation"),
        shape = RoundedCornerShape(30.dp), color = MaterialTheme.colorScheme.surface,
        shadowElevation = 3.dp, border = BorderStroke(.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = .65f))) {
        Row(Modifier.selectableGroup().padding(5.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
            sections.forEach { section ->
                val active = route == section.path
                val background by animateColorAsState(if (active) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent, label = "navigation")
                Column(Modifier.weight(1f).clip(RoundedCornerShape(24.dp)).background(background)
                    .selectable(active, role = Role.Tab, onClick = { navigate(section.path) })
                    .heightIn(min = 54.dp).padding(vertical = 7.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    val tint = if (active) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                    Icon(section.icon, null, Modifier.size(21.dp), tint = tint)
                    Text(section.label, fontSize = 10.sp, lineHeight = 12.sp, color = tint, maxLines = 1)
                }
            }
        }
    }
}

@Composable
internal fun WideNavigation(route: String?, navigate: (String) -> Unit) {
    BoxWithConstraints(Modifier.width(80.dp).fillMaxHeight()) {
        val showBrand = maxHeight >= 540.dp
        Column(Modifier.fillMaxSize().testTag("side-navigation").verticalScroll(rememberScrollState())
            .selectableGroup().padding(horizontal = 8.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (showBrand) {
                Icon(Icons.Outlined.PlayCircleOutline, null, Modifier.padding(vertical = 16.dp).size(30.dp), tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(12.dp))
            }
            sections.forEach { section ->
                val active = route == section.path
                val tint = if (active) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp))
                    .selectable(active, role = Role.Tab, onClick = { navigate(section.path) })
                    .heightIn(min = 60.dp).padding(vertical = 5.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(Modifier.clip(RoundedCornerShape(16.dp)).background(if (active) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent)
                        .padding(horizontal = 14.dp, vertical = 5.dp)) {
                        Icon(section.icon, null, Modifier.size(22.dp), tint = tint)
                    }
                    Text(section.label, style = MaterialTheme.typography.labelSmall, color = tint)
                }
            }
        }
    }
}
