package com.example.asasfans.bili;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;

import java.util.List;
import java.util.Locale;

public class BiliCredentialStore {
    private static final String PREF_NAME = "bili_credentials";
    private static final String KEY_SESSDATA = "SESSDATA";
    private static final String KEY_BILI_JCT = "bili_jct";
    private static final String KEY_DEDE_USER_ID = "DedeUserID";
    private static final String KEY_DEDE_USER_ID_CK = "DedeUserID__ckMd5";
    private static final String KEY_SID = "sid";
    private static final String KEY_REFRESH_TOKEN = "refresh_token";

    private final SharedPreferences preferences;

    public BiliCredentialStore(Context context) {
        Context appContext = context.getApplicationContext();
        try {
            MasterKey masterKey = new MasterKey.Builder(appContext)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build();
            preferences = EncryptedSharedPreferences.create(
                    appContext,
                    PREF_NAME,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            );
        } catch (Exception e) {
            throw new IllegalStateException("Unable to initialize encrypted Bilibili credential storage", e);
        }
    }

    public boolean hasLoginCookie() {
        return !isEmpty(getSessdata());
    }

    public String getSessdata() {
        return preferences.getString(KEY_SESSDATA, "");
    }

    public String getCsrf() {
        return preferences.getString(KEY_BILI_JCT, "");
    }

    public String getRefreshToken() {
        return preferences.getString(KEY_REFRESH_TOKEN, "");
    }

    public void saveRefreshToken(String refreshToken) {
        if (!isEmpty(refreshToken)) {
            preferences.edit().putString(KEY_REFRESH_TOKEN, refreshToken).apply();
        }
    }

    public void saveFromSetCookieHeaders(List<String> setCookieHeaders) {
        SharedPreferences.Editor editor = preferences.edit();
        for (String header : setCookieHeaders) {
            CookiePair pair = parseSetCookieHeader(header);
            putKnownCookie(editor, pair);
        }
        editor.apply();
    }

    public void saveFromCookieString(String cookieHeader) {
        if (isEmpty(cookieHeader)) {
            return;
        }
        SharedPreferences.Editor editor = preferences.edit();
        String[] pairs = cookieHeader.split(";");
        for (String rawPair : pairs) {
            CookiePair pair = parseCookiePair(rawPair);
            putKnownCookie(editor, pair);
        }
        editor.apply();
    }

    public String buildCookieHeader() {
        StringBuilder builder = new StringBuilder();
        appendCookie(builder, KEY_SESSDATA);
        appendCookie(builder, KEY_BILI_JCT);
        appendCookie(builder, KEY_DEDE_USER_ID);
        appendCookie(builder, KEY_DEDE_USER_ID_CK);
        appendCookie(builder, KEY_SID);
        return builder.toString();
    }

    public void clear() {
        preferences.edit().clear().apply();
    }

    private void appendCookie(StringBuilder builder, String key) {
        String value = preferences.getString(key, "");
        if (isEmpty(value)) {
            return;
        }
        if (builder.length() > 0) {
            builder.append("; ");
        }
        builder.append(key).append("=").append(value);
    }

    public static CookiePair parseSetCookieHeader(String header) {
        if (isEmpty(header)) {
            return null;
        }
        String firstPart = header.split(";", 2)[0];
        return parseCookiePair(firstPart);
    }

    private static CookiePair parseCookiePair(String firstPart) {
        if (isEmpty(firstPart)) {
            return null;
        }
        int separator = firstPart.indexOf('=');
        if (separator <= 0) {
            return null;
        }
        String name = firstPart.substring(0, separator).trim();
        String value = firstPart.substring(separator + 1).trim();
        if (isEmpty(name)) {
            return null;
        }
        return new CookiePair(name, value);
    }

    private void putKnownCookie(SharedPreferences.Editor editor, CookiePair pair) {
        if (pair == null) {
            return;
        }
        if (KEY_SESSDATA.equals(pair.name)
                || KEY_BILI_JCT.equals(pair.name)
                || KEY_DEDE_USER_ID.equals(pair.name)
                || KEY_DEDE_USER_ID_CK.equals(pair.name)
                || KEY_SID.equals(pair.name)) {
            editor.putString(pair.name, pair.value);
        }
    }

    private static boolean isEmpty(String value) {
        return value == null || value.isEmpty();
    }

    public static class CookiePair {
        public final String name;
        public final String value;

        CookiePair(String name, String value) {
            this.name = name;
            this.value = value;
        }

        @Override
        public String toString() {
            return String.format(Locale.US, "%s=<redacted>", name);
        }
    }
}
