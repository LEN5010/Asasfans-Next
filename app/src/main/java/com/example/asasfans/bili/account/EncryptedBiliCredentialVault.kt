package com.example.asasfans.bili.account

import android.content.Context
import android.content.SharedPreferences
import android.annotation.SuppressLint
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.example.asasfans.core.model.AppFailure
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Reads the 1.x encryption format in place; credentials never enter Room or DataStore. */
class EncryptedBiliCredentialVault(context: Context) : BiliCredentialVault {
    private val app = context.applicationContext
    private val mutex = Mutex()
    private var preferences: SharedPreferences? = null

    override suspend fun read(): BiliCredentials = access { prefs ->
        BiliCredentials.fromStorage(BiliCredentials.STORED_NAMES.associateWith { prefs.getString(it, "").orEmpty() })
    }

    override suspend fun replace(credentials: BiliCredentials) = access { prefs ->
        // Replace, never merge: missing fields from a new login cannot retain the old account's tokens.
        val editor = prefs.edit().clear()
        credentials.storedValues().forEach { (key, value) -> editor.putString(key, value) }
        if (!editor.commit()) throw AppFailure.LocalStorage()
    }

    @SuppressLint("UseKtx") // KTX edit discards commit's Boolean, which is required for durable logout.
    override suspend fun clear() = access { prefs ->
        if (!prefs.edit().clear().commit()) throw AppFailure.LocalStorage()
    }

    private suspend fun <T> access(block: (SharedPreferences) -> T): T = withContext(Dispatchers.IO) {
        mutex.withLock {
            try {
                val prefs = preferences ?: EncryptedSharedPreferences.create(
                    app, "bili_credentials", MasterKey.Builder(app).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                ).also { preferences = it }
                block(prefs)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                preferences = null
                // Do not delete the encrypted file or expose a keystore exception / secret value.
                throw AppFailure.LocalStorage()
            }
        }
    }
}
