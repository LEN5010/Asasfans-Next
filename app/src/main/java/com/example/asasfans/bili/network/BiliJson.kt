package com.example.asasfans.bili.network

import com.example.asasfans.core.model.AppFailure
import kotlinx.serialization.json.*
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

internal fun JsonObject.text(name: String) = (this[name] as? JsonPrimitive)?.contentOrNull.orEmpty()
internal fun JsonObject.number(name: String) = (this[name] as? JsonPrimitive)?.longOrNull
internal fun JsonObject.boolean(name: String) = (this[name] as? JsonPrimitive)?.booleanOrNull
internal fun JsonObject.obj(name: String) = this[name] as? JsonObject
internal fun JsonObject.requireObject(name: String) = obj(name) ?: throw AppFailure.InvalidResponse()
internal fun JsonObject.array(name: String): JsonArray? = when (val value = this[name]) {
    null, JsonNull -> null
    is JsonArray -> value
    else -> throw AppFailure.InvalidResponse()
}
internal fun JsonObject.data(): JsonObject = requireObject("data").also {
    // Some WBI failures are business-code 0 with only a challenge, never an empty result.
    if (it.text("v_voucher").isNotBlank()) throw AppFailure.RiskControl(0)
}
internal fun JsonObject.positive(name: String) = number(name)?.takeIf { it > 0 } ?: throw AppFailure.InvalidResponse()
internal fun milliseconds(seconds: Long?) = seconds?.takeIf { it in 0..Long.MAX_VALUE / 1000 }?.times(1000) ?: 0L
internal fun count(value: Long?) = value?.takeIf { it >= 0 }
internal fun httpsUrl(value: String): String {
    val normalized = if (value.startsWith("//")) "https:$value" else value
    val url = normalized.toHttpUrlOrNull() ?: return ""
    if (url.username.isNotEmpty() || url.password.isNotEmpty()) return ""
    if (url.isHttps) return url.toString()
    return if (listOf("hdslb.com", "bilivideo.com", "bilivideo.cn").any { url.host == it || url.host.endsWith(".$it") })
        url.newBuilder().scheme("https").port(443).build().toString() else ""
}
internal fun requireBvid(value: String): String {
    if (!value.matches(Regex("BV[0-9A-Za-z]{10}"))) throw AppFailure.InvalidInput("BV 号格式不正确")
    return value
}
