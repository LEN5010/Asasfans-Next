package com.example.asasfans.bili;

import android.text.TextUtils;

import androidx.annotation.OptIn;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.common.util.UnstableApi;

import com.google.gson.Gson;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import okhttp3.FormBody;
import okhttp3.HttpUrl;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

public class BiliApiClient {
    public static final String WEB_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
    public static final String BILI_REFERER = "https://www.bilibili.com/";

    private final OkHttpClient client;
    private final BiliCredentialStore credentialStore;
    private final Gson gson = new Gson();

    public BiliApiClient(BiliCredentialStore credentialStore) {
        this.credentialStore = credentialStore;
        this.client = new OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(15, TimeUnit.SECONDS)
                .writeTimeout(15, TimeUnit.SECONDS)
                .build();
    }

    public <T> T get(String url, Class<T> type) throws IOException {
        return get(url, BILI_REFERER, type);
    }

    public <T> T get(String url, String referer, Class<T> type) throws IOException {
        Request request = applyHeaders(new Request.Builder().url(url), referer)
                .get()
                .build();
        return executeForJson(request, type);
    }

    public <T> T postForm(String url, FormBody formBody, Class<T> type) throws IOException {
        Request request = applyHeaders(new Request.Builder().url(url), BILI_REFERER)
                .post(formBody)
                .build();
        return executeForJson(request, type);
    }

    public Response executeRaw(Request request) throws IOException {
        return client.newCall(request).execute();
    }

    public Request.Builder applyHeaders(Request.Builder builder, String referer) {
        builder.header("User-Agent", WEB_USER_AGENT)
                .header("Referer", TextUtils.isEmpty(referer) ? BILI_REFERER : referer);
        String cookie = credentialStore.buildCookieHeader();
        if (!TextUtils.isEmpty(cookie)) {
            builder.header("Cookie", cookie);
        }
        return builder;
    }

    @OptIn(markerClass = UnstableApi.class)
    public OkHttpDataSource.Factory newMediaDataSourceFactory(String referer) {
        Map<String, String> headers = new HashMap<>();
        headers.put("User-Agent", WEB_USER_AGENT);
        headers.put("Referer", TextUtils.isEmpty(referer) ? BILI_REFERER : referer);
        String cookie = credentialStore.buildCookieHeader();
        if (!TextUtils.isEmpty(cookie)) {
            headers.put("Cookie", cookie);
        }
        return new OkHttpDataSource.Factory(client)
                .setDefaultRequestProperties(headers);
    }

    public static String appendQuery(String baseUrl, String query) {
        return baseUrl + (baseUrl.contains("?") ? "&" : "?") + query;
    }

    public static HttpUrl.Builder urlBuilder(String url) {
        HttpUrl httpUrl = HttpUrl.parse(url);
        if (httpUrl == null) {
            throw new IllegalArgumentException("Invalid URL: " + url);
        }
        return httpUrl.newBuilder();
    }

    private <T> T executeForJson(Request request, Class<T> type) throws IOException {
        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("HTTP " + response.code());
            }
            if (response.body() == null) {
                throw new IOException("Empty response body");
            }
            return gson.fromJson(response.body().string(), type);
        }
    }
}
