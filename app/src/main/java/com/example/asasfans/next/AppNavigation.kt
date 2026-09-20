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
    MainSection("tools", "工具", Icons.Outlined.Widgets),
    MainSection("library", "资料库", Icons.Outlined.VideoLibrary),
    MainSection("mine", "我的", Icons.Outlined.Person),
)

@Composable
internal fun CompactNavigation(route: String?, navigate: (String) -> Unit, toolsOpen: Boolean, openTools: () -> Unit) {
    Box(Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp).fillMaxWidth().testTag("bottom-navigation")) {
        Surface(Modifier.matchParentSize(), shape = RoundedCornerShape(30.dp), color = MaterialTheme.colorScheme.surface,
            shadowElevation = 3.dp, border = BorderStroke(.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = .65f))) {}
        Row(Modifier.selectableGroup().padding(5.dp), horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically) {
            sections.forEach { section ->
                if (section.path == "tools") {
                    Column(Modifier.weight(1f).offset(y = (-8).dp), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Surface(onClick = openTools, modifier = Modifier.size(48.dp).testTag("tools-button"),
                            shape = RoundedCornerShape(18.dp), shadowElevation = 6.dp,
                            color = DianaPink, contentColor = MaterialTheme.colorScheme.onSecondaryContainer) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(if (toolsOpen) Icons.Outlined.Close else section.icon, "工具", Modifier.size(25.dp), tint = Color(0xFF451E2C))
                            }
                        }
                        Text(section.label, fontSize = 10.sp, lineHeight = 12.sp, color = MaterialTheme.colorScheme.primary)
                    }
                } else {
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
}

@Composable
internal fun WideNavigation(route: String?, navigate: (String) -> Unit, toolsOpen: Boolean, openTools: () -> Unit) {
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
                val active = if (section.path == "tools") toolsOpen else route == section.path
                val tint = if (active) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp))
                    .selectable(active, role = if (section.path == "tools") Role.Button else Role.Tab,
                        onClick = { if (section.path == "tools") openTools() else navigate(section.path) })
                    .heightIn(min = 60.dp).padding(vertical = 5.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(Modifier.clip(RoundedCornerShape(16.dp)).background(if (section.path == "tools") DianaPink else if (active) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent)
                        .padding(horizontal = 14.dp, vertical = 5.dp)) {
                        Icon(section.icon, null, Modifier.size(22.dp), tint = if (section.path == "tools") Color(0xFF451E2C) else tint)
                    }
                    Text(section.label, style = MaterialTheme.typography.labelSmall, color = tint)
                }
            }
        }
    }
}
