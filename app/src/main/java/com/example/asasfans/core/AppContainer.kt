package com.example.asasfans.core

import android.content.Context
import com.example.asasfans.bili.account.BiliAccountRepository
import com.example.asasfans.bili.account.EncryptedBiliCredentialVault
import com.example.asasfans.bili.account.HttpBiliAccountApi
import com.example.asasfans.bili.content.BiliContentRepository
import com.example.asasfans.bili.network.BiliGateway
import com.example.asasfans.bili.network.BiliMediaDataSource
import com.example.asasfans.bili.network.HttpBiliTransport
import com.example.asasfans.core.data.FeedRepository
import com.example.asasfans.core.data.LibraryRepository
import com.example.asasfans.core.data.CurationRepository
import com.example.asasfans.core.data.StartupCoordinator
import com.example.asasfans.core.database.AsasDatabase
import com.example.asasfans.core.database.LegacyImporter
import com.example.asasfans.core.network.CommunityVideoSource
import com.example.asasfans.core.network.JsonHttpClient
import com.example.asasfans.core.preferences.AppPreferences
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient

/** Application-owned graph for the new implementation; no Activity or legacy UI dependency. */
class AppContainer(context: Context) {
    private val app = context.applicationContext
    val database = AsasDatabase.open(app)
    val preferences = AppPreferences.open(app)
    private val importer = LegacyImporter(database, app.getDatabasePath("blackList.db"))
    val startup = StartupCoordinator(
        importAssets = { importer.importIfNeeded(); Unit },
        importPreferences = { preferences.importLegacy(app) },
    )
    val httpClient = OkHttpClient.Builder().connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS).callTimeout(25, TimeUnit.SECONDS).build()
    private val community = CommunityVideoSource(JsonHttpClient(httpClient))
    private val biliTransport = HttpBiliTransport(JsonHttpClient(httpClient))
    val account = BiliAccountRepository(EncryptedBiliCredentialVault(app), HttpBiliAccountApi(biliTransport))
    val bili = BiliContentRepository(BiliGateway(biliTransport, account::requestCredentials))
    val biliMedia = BiliMediaDataSource(httpClient, account::currentCredentials)
    val library = LibraryRepository(database, startup::requireReady)
    val curation = CurationRepository(database, startup::requireReady)
    val discovery = FeedRepository(database, "community", community::load, startup::requireReady)
    val search = FeedRepository(database, "bilibili-search", bili::search, startup::requireReady)
}
