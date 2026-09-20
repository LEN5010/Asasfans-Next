package com.example.asasfans.next

import android.graphics.Bitmap
import androidx.core.graphics.createBitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import com.example.asasfans.BuildConfig
import com.example.asasfans.bili.account.*
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.preferences.*
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import kotlinx.coroutines.*

@Composable
fun AccountPage(vm: MainViewModel, rules: () -> Unit, web: (String) -> Unit) {
    val account by vm.graph.account.state.collectAsStateWithLifecycle()
    val preferences by vm.preferences.collectAsStateWithLifecycle()
    val later by vm.watchLater.collectAsStateWithLifecycle()
    val collections by vm.collections.collectAsStateWithLifecycle()
    val subscriptions by vm.subscriptions.collectAsStateWithLifecycle()
    var showQr by remember { mutableStateOf(false) }
    var confirmLogout by remember { mutableStateOf(false) }
    var picker by remember { mutableStateOf<String?>(null) }
    var accountMenu by remember { mutableStateOf(false) }
    val themeName = when (preferences.theme) { ThemeMode.SYSTEM -> "跟随系统"; ThemeMode.LIGHT -> "浅色"; ThemeMode.DARK -> "深色" }
    Column {
        PageHeader("我的")
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            CreatorAvatar(account.profile?.name ?: "A", account.profile?.avatarUrl.orEmpty(), size = 52)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(account.profile?.name ?: "未登录", style = MaterialTheme.typography.titleMedium)
                                Text(when (account.status) {
                                    AccountStatus.NOT_LOADED -> "读取中…"
                                    AccountStatus.SIGNED_OUT -> "Bilibili"
                                    AccountStatus.SIGNED_IN -> "已登录 Bilibili"
                                    AccountStatus.UNVERIFIED -> "待验证"
                                    AccountStatus.EXPIRED -> "登录已过期"
                                    AccountStatus.STORAGE_ERROR -> "账号读取失败"
                                    AccountStatus.LOGOUT_PENDING -> "退出未完成"
                                }, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Box {
                                IconButton(onClick = { accountMenu = true }) { Icon(Icons.Outlined.MoreVert, "账号操作") }
                                DropdownMenu(accountMenu, { accountMenu = false }) {
                                    DropdownMenuItem(text = { Text(if (account.checking) "校验中…" else "校验账号") }, enabled = !account.checking,
                                        onClick = { accountMenu = false; vm.action { vm.graph.account.refresh() } })
                                    if (account.status == AccountStatus.STORAGE_ERROR || account.status == AccountStatus.LOGOUT_PENDING) {
                                        DropdownMenuItem(text = { Text("重试") }, onClick = { accountMenu = false; vm.action { vm.graph.account.retryStorage() } })
                                    }
                                    if (account.status != AccountStatus.SIGNED_OUT) DropdownMenuItem(text = { Text("退出账号") }, onClick = { accountMenu = false; confirmLogout = true })
                                }
                            }
                        }
                        if (account.status != AccountStatus.SIGNED_IN) FilledTonalButton(onClick = { showQr = true }) {
                            Icon(Icons.Outlined.QrCode, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("扫码登录")
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceAround) {
                            listOf(later.size to "稍后看", collections.size to "收藏夹", subscriptions.size to "订阅").forEach { (count, label) ->
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(count.toString(), style = MaterialTheme.typography.titleLarge)
                                    Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }
            }
            account.failure?.let { failure -> item { MessagePanel("账号暂不可用", failure.userMessage) } }
            item { SectionTitle("偏好设置") }
            item { Surface(shape = RoundedCornerShape(16.dp)) { Column {
                SettingsRow(Icons.Outlined.Palette, "外观", themeName, { picker = "theme" })
                SettingsRow(Icons.Outlined.PlayCircleOutline, "播放方式", if (preferences.playbackMode == PlaybackMode.APP) "应用内" else "哔哩哔哩", { picker = "playback" })
                SettingsRow(Icons.Outlined.Tune, "内容规则", onClick = rules)
            } } }
            item { SectionTitle("通用") }
            item { Surface(shape = RoundedCornerShape(16.dp)) { Column {
                SettingsRow(Icons.Outlined.CleaningServices, "清除列表缓存", onClick = { vm.action { vm.graph.library.clearFeedCache(); vm.notify("列表缓存已清除") } })
                SettingsRow(Icons.Outlined.Language, "社区导航", onClick = { web("https://nav.asoul.us.kg") })
                SettingsRow(Icons.Outlined.Info, "关于 Asasfans", BuildConfig.VERSION_NAME, { picker = "about" })
            } } }
        }
    }
    if (showQr) QrDialog(vm, { showQr = false })
    if (confirmLogout) AlertDialog(onDismissRequest = { confirmLogout = false }, title = { Text("退出 B 站账号？") },
        confirmButton = { TextButton(onClick = { vm.action { vm.graph.account.logout() }; confirmLogout = false }) { Text("退出") } },
        dismissButton = { TextButton(onClick = { confirmLogout = false }) { Text("取消") } })
    picker?.let { current -> AlertDialog(onDismissRequest = { picker = null }, title = { Text(when (current) { "theme" -> "外观"; "playback" -> "播放方式"; else -> "Asasfans Next" }) }, text = {
        Column {
            when (current) {
                "theme" -> ThemeMode.entries.forEach { mode -> SettingsRow(Icons.Outlined.Palette,
                    when (mode) { ThemeMode.SYSTEM -> "跟随系统"; ThemeMode.LIGHT -> "浅色"; ThemeMode.DARK -> "深色" },
                    if (mode == preferences.theme) "✓" else null, { vm.action { vm.graph.preferences.setTheme(mode) }; picker = null }) }
                "playback" -> PlaybackMode.entries.forEach { mode -> SettingsRow(Icons.Outlined.PlayCircleOutline,
                    if (mode == PlaybackMode.APP) "应用内播放" else "哔哩哔哩", if (mode == preferences.playbackMode) "✓" else null,
                    { vm.action { vm.graph.preferences.setPlaybackMode(mode) }; picker = null }) }
                else -> { Text("${BuildConfig.VERSION_NAME} · GPL-2.0"); Spacer(Modifier.height(12.dp)); Text("非官方 A-SOUL 客户端") }
            }
        }
    }, confirmButton = { TextButton(onClick = { picker = null }) { Text("关闭") } }) }
}

@Composable
private fun QrDialog(vm: MainViewModel, dismiss: () -> Unit) {
    val owner = LocalLifecycleOwner.current
    var bitmap by remember { mutableStateOf<Bitmap?>(null) }
    var status by remember { mutableStateOf("正在申请二维码…") }
    var attempt by remember { mutableIntStateOf(0) }
    var canRetry by remember { mutableStateOf(false) }
    LaunchedEffect(attempt) {
        canRetry = false; bitmap = null
        var current: LoginQr? = null
        try {
            current = vm.graph.account.createQr() ?: return@LaunchedEffect
            bitmap = withContext(Dispatchers.Default) {
                val matrix = MultiFormatWriter().encode(current.url, BarcodeFormat.QR_CODE, 320, 320)
                createBitmap(320, 320).apply {
                    setPixels(IntArray(320 * 320) { i -> if (matrix[i % 320, i / 320]) android.graphics.Color.BLACK else android.graphics.Color.WHITE }, 0, 320, 0, 0, 320, 320)
                }
            }
            owner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                while (isActive) {
                    val result = vm.graph.account.pollQr(current)
                    status = when (result) { QrStatus.WAITING -> "使用哔哩哔哩 App 扫码"; QrStatus.SCANNED -> "已扫码，请在手机上确认"; QrStatus.EXPIRED -> "二维码已过期"; QrStatus.SUCCESS -> "登录凭据已保存"; QrStatus.SUPERSEDED -> "此次登录已取消" }
                    if (result == QrStatus.SUCCESS) { vm.graph.account.refresh(); dismiss(); break }
                    if (result == QrStatus.EXPIRED || result == QrStatus.SUPERSEDED) { canRetry = true; break }
                    delay(2000)
                }
            }
        } catch (error: CancellationException) { throw error }
        catch (error: AppFailure) { status = error.userMessage; canRetry = true }
        finally { withContext(NonCancellable) { current?.let { vm.graph.account.cancelQr(it) } } }
    }
    AlertDialog(onDismissRequest = dismiss, title = { Text("B 站扫码登录") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            bitmap?.let { Image(it.asImageBitmap(), "登录二维码", Modifier.fillMaxWidth().aspectRatio(1f)) }
            Text(status)
        }
    }, confirmButton = { if (canRetry) TextButton(onClick = { attempt++ }) { Text("重新生成") } }, dismissButton = { TextButton(onClick = dismiss) { Text("关闭") } })
}
