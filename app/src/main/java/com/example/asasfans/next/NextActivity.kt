package com.example.asasfans.next

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.LocalActivity
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.core.view.WindowCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import com.example.asasfans.core.data.StartupState
import com.example.asasfans.core.model.AppFailure
import com.example.asasfans.core.preferences.PlaybackMode
import com.example.asasfans.core.preferences.ThemeMode

class NextActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { NextApp(application as NextApplication) }
    }
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NextApp(app: NextApplication) {
    val vm: MainViewModel = viewModel(factory = viewModelFactory { initializer { MainViewModel(app.container, createSavedStateHandle()) } })
    val preferences by vm.preferences.collectAsStateWithLifecycle()
    val dark = when (preferences.theme) { ThemeMode.SYSTEM -> isSystemInDarkTheme(); ThemeMode.DARK -> true; ThemeMode.LIGHT -> false }
    val activity = LocalActivity.current
    SideEffect { activity?.let { current ->
        WindowCompat.getInsetsController(current.window, current.window.decorView).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    } }
    val colors = if (dark) darkColorScheme(
        primary = Color(0xFFBCC5F4), onPrimary = Color(0xFF263259), primaryContainer = Color(0xFF39466F),
        secondaryContainer = Color(0xFF333F61), onSecondaryContainer = Color(0xFFDBE2FF),
        background = Color(0xFF121317), surface = Color(0xFF1B1C22), onSurface = Color(0xFFE5E5EB),
        onSurfaceVariant = Color(0xFFADB0BD), outline = Color(0xFF858896), outlineVariant = Color(0xFF34363F),
        surfaceContainerLow = Color(0xFF202127), surfaceContainer = Color(0xFF24252D), surfaceContainerHigh = Color(0xFF2D2F38))
    else lightColorScheme(
        primary = Color(0xFF53649E), onPrimary = Color.White, primaryContainer = Color(0xFFDEE4FC),
        secondaryContainer = Color(0xFFE1E6FA), onSecondaryContainer = Color(0xFF354572),
        background = Color(0xFFF7F8FC), surface = Color.White, onSurface = Color(0xFF22232B),
        onSurfaceVariant = Color(0xFF656875), outline = Color(0xFF868A98), outlineVariant = Color(0xFFE1E3EB),
        surfaceContainerLow = Color(0xFFF0F1F7), surfaceContainer = Color(0xFFECEEF5), surfaceContainerHigh = Color(0xFFE6E8F0))
    MaterialTheme(colorScheme = colors) {
        val nav = rememberNavController()
        val entry by nav.currentBackStackEntryAsState()
        val route = entry?.destination?.route
        val startup by vm.startup.collectAsStateWithLifecycle()
        val snackbar = remember { SnackbarHostState() }
        val context = LocalContext.current
        var externalSequence by remember { mutableLongStateOf(0) }
        LaunchedEffect(vm) { vm.messages.collect { notice ->
            if (snackbar.showSnackbar(notice.text, notice.actionLabel) == SnackbarResult.ActionPerformed) notice.action?.let { vm.action(it) }
        } }
        fun external(url: String) {
            try { context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri())) }
            catch (_: ActivityNotFoundException) { vm.action { vm.notify("未找到可打开此链接的应用") } }
        }
        val openVideo: (String, Long?, Long?, Boolean) -> Unit = { bvid, part, at, forceApp ->
            if (!forceApp && preferences.playbackMode == PlaybackMode.EXTERNAL) {
                val sequence = ++externalSequence
                val origin = nav.currentBackStackEntry?.id
                vm.action {
                    if (!bvid.matches(Regex("BV[0-9A-Za-z]{10}"))) throw AppFailure.InvalidInput("视频标识无法识别")
                    val number = if (part != null) vm.graph.bili.detail(bvid).parts.firstOrNull { it.id == part }?.number
                        ?: throw AppFailure.InvalidInput("原分 P 已失效，请从视频详情重新选择") else 1
                    val url = "https://www.bilibili.com/video/$bvid".toUri().buildUpon()
                        .appendQueryParameter("p", number.toString()).appendQueryParameter("t", ((at ?: 0) / 1000).toString()).build()
                    if (sequence == externalSequence && nav.currentBackStackEntry?.id == origin) external(url.toString())
                }
            }
            else nav.navigate("video/${Uri.encode(bvid)}?part=${part ?: -1}&at=${at ?: -1}")
        }
        val openWeb: (String) -> Unit = { nav.navigate("web/${Uri.encode(it)}") }
        val rootPage = sections.any { it.path == route }
        fun navigate(path: String) {
            nav.navigate(path) { popUpTo("today") { saveState = true }; launchSingleTop = true; restoreState = true }
        }
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val wide = maxWidth >= 720.dp
            Scaffold(
                snackbarHost = { SnackbarHost(snackbar) },
                topBar = {
                    if (route == "rules") TopAppBar(title = { Text("内容规则") }, navigationIcon = {
                        IconButton(onClick = { nav.popBackStack() }) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") }
                    })
                },
                bottomBar = {
                    if (rootPage && !wide) Box(Modifier.navigationBarsPadding()) { CompactNavigation(route, ::navigate) }
                },
            ) { padding ->
                Row(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) {
                    if (rootPage && wide) WideNavigation(route, ::navigate)
                    Surface(Modifier.weight(1f).fillMaxHeight(), color = MaterialTheme.colorScheme.background) {
                        when (val state = startup) {
                            is StartupState.Failed -> MessagePanel("本地数据尚未就绪", state.message, "重试") { vm.action { vm.graph.startup.initialize() } }
                            StartupState.NotStarted, StartupState.Migrating -> MessagePanel("正在载入…")
                            StartupState.Ready -> NavHost(nav, startDestination = "today") {
                                composable("today") { TodayPage(vm, { b, p, t -> openVideo(b, p, t, false) }, { navigate("discover") }, { navigate("library") }, openWeb) }
                                composable("discover") { DiscoverPage(vm, { openVideo(it, null, null, false) }, { openVideo(it, null, null, true) }, ::external, openWeb, { nav.navigate("rules") }) }
                                composable("following") { FollowingPage(vm) }
                                composable("library") { LibraryPage(vm) { b, p, t -> openVideo(b, p, t, false) } }
                                composable("mine") { AccountPage(vm, { nav.navigate("rules") }, openWeb) }
                                composable("rules") { RulesPage(vm) }
                                composable("web/{url}") { page -> WebPage(page.arguments?.getString("url").orEmpty(), ::external) { nav.popBackStack() } }
                                composable("video/{bvid}?part={part}&at={at}", arguments = listOf(
                                    navArgument("part") { type = NavType.LongType; defaultValue = -1L },
                                    navArgument("at") { type = NavType.LongType; defaultValue = -1L },
                                )) { page ->
                                    val playerVm: PlayerViewModel = viewModel(factory = viewModelFactory { initializer {
                                        PlayerViewModel(app, page.arguments!!.getString("bvid").orEmpty(),
                                            page.arguments!!.getLong("part").takeIf { it > 0 }, page.arguments!!.getLong("at").takeIf { it >= 0 }, page.savedStateHandle)
                                    } })
                                    PlayerPage(playerVm, vm, { nav.popBackStack() }, ::external)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
