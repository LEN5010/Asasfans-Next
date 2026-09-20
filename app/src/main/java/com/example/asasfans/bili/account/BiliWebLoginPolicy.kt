package com.example.asasfans.bili.account

import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/** Public navigation/cookie scopes only. Never contains a password, session value or JS bridge. */
internal object BiliWebLoginPolicy {
    const val LOGIN_URL = "https://passport.bilibili.com/login"
    const val COOKIE_ORIGIN = "https://www.bilibili.com/"
    private val pageHosts = setOf("passport.bilibili.com", "account.bilibili.com", "www.bilibili.com", "m.bilibili.com")
    private val cookieHosts = pageHosts + setOf("bilibili.com", "api.bilibili.com", "space.bilibili.com")
    val cookieOrigins = cookieHosts.map { "https://$it/" }

    fun allowsPage(value: String): Boolean {
        val url = value.toHttpUrlOrNull() ?: return false
        return url.isHttps && url.port == 443 && url.host in pageHosts && url.username.isEmpty() && url.password.isEmpty()
    }

    fun hasSession(header: String): Boolean = header.split(';').any {
        it.substringBefore('=').trim() == "SESSDATA" && it.substringAfter('=', "").isNotBlank()
    }

    fun containsLoginCookies(header: String): Boolean = header.split(';').any {
        it.substringBefore('=').trim() in BiliCredentials.COOKIE_NAMES && it.substringAfter('=', "").isNotEmpty()
    }

    fun expiredCookies(): List<Pair<String, String>> = buildList {
        for (host in cookieHosts) for (name in BiliCredentials.COOKIE_NAMES) {
            val expired = "$name=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly"
            add("https://$host/" to expired)
            add("https://$host/" to "$expired; Domain=.$host")
        }
    }
}
