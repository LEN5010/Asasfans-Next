package com.example.asasfans.bili.account

import com.example.asasfans.core.model.AppFailure
import okhttp3.Cookie
import okhttp3.HttpUrl

/** Login secrets have no generated toString/copy/serialization implementation. */
class BiliCredentials private constructor(private val values: Map<String, String>) {
    val hasSession: Boolean get() = !values["SESSDATA"].isNullOrEmpty()
    internal fun storedValues(): Map<String, String> = values.toMap()
    fun cookieHeader(): String = COOKIE_NAMES.mapNotNull { name ->
        values[name]?.takeIf(String::isNotEmpty)?.let { "$name=$it" }
    }.joinToString("; ")
    override fun toString() = "BiliCredentials(<redacted>)"

    companion object {
        internal val COOKIE_NAMES = setOf("SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5", "sid")
        internal val STORED_NAMES = COOKIE_NAMES + "refresh_token"
        val Empty = BiliCredentials(emptyMap())

        internal fun fromStorage(values: Map<String, String>): BiliCredentials {
            val known = values.filterKeys { it in STORED_NAMES }
            if (known.values.any { !safeValue(it) }) throw AppFailure.LocalStorage()
            return BiliCredentials(known.toMap())
        }

        fun fromSetCookies(origin: HttpUrl, headers: List<String>, refreshToken: String): BiliCredentials {
            val values = headers.mapNotNull { Cookie.parse(origin, it) }
                .filter { it.name in COOKIE_NAMES && it.matches(origin) && it.expiresAt > System.currentTimeMillis() }
                .associate { it.name to it.value }.toMutableMap()
            if (refreshToken.isNotEmpty()) values["refresh_token"] = refreshToken
            return fromLogin(values)
        }

        /** Only called after the official WebView flow returns its CookieManager snapshot. */
        fun fromWebCookies(header: String): BiliCredentials {
            val values = header.split(';').mapNotNull { pair ->
                val index = pair.indexOf('=')
                if (index < 1) null else pair.substring(0, index).trim() to pair.substring(index + 1).trim()
            }.filter { it.first in COOKIE_NAMES }.toMap()
            return fromLogin(values)
        }

        private fun fromLogin(values: Map<String, String>): BiliCredentials {
            if (values.values.any { !safeValue(it) } || values["SESSDATA"].isNullOrBlank()) {
                throw AppFailure.InvalidResponse()
            }
            return BiliCredentials(values.toMap())
        }

        private fun safeValue(value: String) = value.length <= 8192 && value.all {
            it.code in 0x21..0x7e && it != ';' && it != ',' && it != '"' && it != '\\'
        }
    }
}

interface BiliCredentialVault {
    suspend fun read(): BiliCredentials
    suspend fun replace(credentials: BiliCredentials)
    suspend fun clear()
}
