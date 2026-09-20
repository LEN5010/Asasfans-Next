package com.example.asasfans.bili.account

import com.example.asasfans.core.model.AppFailure

data class BiliProfile(val mid: Long, val name: String, val avatarUrl: String, val verifiedAtMs: Long)
enum class AccountStatus { NOT_LOADED, SIGNED_OUT, UNVERIFIED, SIGNED_IN, EXPIRED, STORAGE_ERROR, LOGOUT_PENDING }
data class AccountState(
    val status: AccountStatus = AccountStatus.NOT_LOADED,
    val profile: BiliProfile? = null,
    val checking: Boolean = false,
    val failure: AppFailure? = null,
)

/** Opaque capability: responses may install credentials only for this still-active login attempt. */
class LoginTicket internal constructor(internal val generation: Long, internal val attempt: Long) {
    override fun toString() = "LoginTicket(<redacted>)"
}
class LoginQr internal constructor(
    internal val ticket: LoginTicket,
    internal val key: String,
    val url: String,
    val expiresAtMs: Long,
) {
    override fun toString() = "LoginQr(<redacted>)"
}
enum class QrStatus { WAITING, SCANNED, EXPIRED, SUCCESS, SUPERSEDED }
class GeneratedQr(val key: String, val url: String) {
    override fun toString() = "GeneratedQr(<redacted>)"
}
class PolledQr(val status: QrStatus, val credentials: BiliCredentials? = null) {
    override fun toString() = "PolledQr(status=$status, <redacted>)"
}

interface BiliAccountApi {
    /** null means an explicit -101 / isLogin=false response, not a network failure. */
    suspend fun profile(credentials: BiliCredentials): BiliProfile?
    suspend fun generateQr(): GeneratedQr
    suspend fun pollQr(key: String): PolledQr
}
