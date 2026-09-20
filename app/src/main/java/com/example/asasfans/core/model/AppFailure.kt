package com.example.asasfans.core.model

/** Messages are product-owned: never expose raw headers or an arbitrary server response. */
sealed class AppFailure(val userMessage: String) : Exception(userMessage) {
    class Network : AppFailure("网络暂不可用，请检查连接后重试")
    class Http(val status: Int) : AppFailure("内容来源暂时不可用（HTTP $status）")
    class LoginRequired : AppFailure("登录已失效或此功能需要登录，请重新验证 B 站账号")
    class RiskControl(val code: Int) : AppFailure("B 站暂时限制了这次请求，请稍后重试；未登录时可尝试登录")
    class Unavailable : AppFailure("内容已失效或当前账号无法访问")
    class CommentsClosed : AppFailure("此视频的评论区已关闭")
    class InvalidResponse : AppFailure("内容来源返回了无法识别的数据，请稍后重试")
    class LocalStorage : AppFailure("本地数据暂时无法读写，请检查存储空间后重试")
    class Business(val code: Int) : AppFailure("内容来源返回错误（$code）")
    class InvalidInput(message: String) : AppFailure(message)
}
