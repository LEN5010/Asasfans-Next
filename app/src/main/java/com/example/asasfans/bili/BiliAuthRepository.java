package com.example.asasfans.bili;

import java.io.IOException;

import okhttp3.HttpUrl;
import okhttp3.Request;
import okhttp3.Response;

public class BiliAuthRepository {
    private static final String QR_GENERATE_URL = "https://passport.bilibili.com/x/passport-login/web/qrcode/generate";
    private static final String QR_POLL_URL = "https://passport.bilibili.com/x/passport-login/web/qrcode/poll";
    static final String NAV_URL = "https://api.bilibili.com/x/web-interface/nav";

    private final BiliApiClient apiClient;
    private final BiliCredentialStore credentialStore;

    public BiliAuthRepository(BiliApiClient apiClient, BiliCredentialStore credentialStore) {
        this.apiClient = apiClient;
        this.credentialStore = credentialStore;
    }

    public BiliModels.QrGenerateResponse generateQrCode() throws IOException {
        BiliModels.QrGenerateResponse response = apiClient.get(QR_GENERATE_URL, BiliModels.QrGenerateResponse.class);
        if (response == null || !response.isSuccess() || response.data == null) {
            throw new BiliException(response == null ? -1 : response.code, response == null ? "二维码申请失败" : response.message);
        }
        return response;
    }

    public BiliModels.QrPollResponse pollQrCode(String qrcodeKey) throws IOException {
        HttpUrl url = BiliApiClient.urlBuilder(QR_POLL_URL)
                .addQueryParameter("qrcode_key", qrcodeKey)
                .build();
        Request request = apiClient.applyHeaders(new Request.Builder().url(url), BiliApiClient.BILI_REFERER)
                .get()
                .build();
        try (Response rawResponse = apiClient.executeRaw(request)) {
            if (!rawResponse.isSuccessful()) {
                throw new IOException("HTTP " + rawResponse.code());
            }
            if (rawResponse.body() == null) {
                throw new IOException("Empty response body");
            }
            BiliModels.QrPollResponse response = new com.google.gson.Gson().fromJson(rawResponse.body().string(), BiliModels.QrPollResponse.class);
            if (response != null && response.data != null && response.data.code == 0) {
                credentialStore.saveFromSetCookieHeaders(rawResponse.headers("Set-Cookie"));
                credentialStore.saveRefreshToken(response.data.refreshToken);
            }
            return response;
        }
    }

    public BiliModels.NavResponse getNav() throws IOException {
        return apiClient.get(NAV_URL, BiliModels.NavResponse.class);
    }

    public boolean isLoggedIn() throws IOException {
        BiliModels.NavResponse nav = getNav();
        return nav != null && nav.data != null && nav.data.isLogin;
    }

    public void logout() {
        credentialStore.clear();
    }
}
