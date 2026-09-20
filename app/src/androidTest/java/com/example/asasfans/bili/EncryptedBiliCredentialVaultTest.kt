package com.example.asasfans.bili

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.asasfans.bili.account.BiliCredentials
import com.example.asasfans.bili.account.EncryptedBiliCredentialVault
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class EncryptedBiliCredentialVaultTest {
    @Test fun legacyEncryptedFileIsReadableAndReplacedAtomicallyWithoutPlaintext() = runBlocking {
        val base = ApplicationProvider.getApplicationContext<Context>()
        val prefix = "vault-test-${System.nanoTime()}-"
        // Isolate the fixture file; do not read/clear any account used by an installed app.
        val context = object : ContextWrapper(base) {
            override fun getApplicationContext(): Context = this
            override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
                base.getSharedPreferences(prefix + name, mode)
        }
        val fileName = "${prefix}bili_credentials"
        try {
            withContext(Dispatchers.IO) {
                val legacy = BiliCredentialStore(context)
                legacy.saveFromCookieString("SESSDATA=fixture-legacy; bili_jct=fixture-csrf; DedeUserID=123")
                legacy.saveRefreshToken("fixture-refresh")
                // Flush the underlying test file before inspecting on-disk ciphertext.
                base.getSharedPreferences(fileName, Context.MODE_PRIVATE).edit().commit()
            }
            val vault = EncryptedBiliCredentialVault(context)
            assertEquals("SESSDATA=fixture-legacy; bili_jct=fixture-csrf; DedeUserID=123", vault.read().cookieHeader())
            vault.replace(BiliCredentials.fromWebCookies("SESSDATA=fixture-new"))
            val reopened = EncryptedBiliCredentialVault(context)
            assertEquals("SESSDATA=fixture-new", reopened.read().cookieHeader())
            val raw = withContext(Dispatchers.IO) {
                File(base.applicationInfo.dataDir, "shared_prefs/$fileName.xml").readText()
            }
            assertFalse(raw.contains("fixture-new"))
            assertFalse(raw.contains("fixture-legacy"))
            assertFalse(raw.contains("SESSDATA"))
            vault.clear()
            assertFalse(EncryptedBiliCredentialVault(context).read().hasSession)
        } finally { base.deleteSharedPreferences(fileName) }
    }
}
