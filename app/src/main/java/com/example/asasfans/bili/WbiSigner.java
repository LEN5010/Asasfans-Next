package com.example.asasfans.bili;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class WbiSigner {
    private static final int[] MIXIN_KEY_ENC_TAB = new int[]{
            46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
            27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
            37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
            22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    };

    private String imgKey;
    private String subKey;
    private long keyLoadedAtDay = -1;

    public synchronized void setKeys(String imgUrl, String subUrl) {
        imgKey = extractKey(imgUrl);
        subKey = extractKey(subUrl);
        keyLoadedAtDay = currentDay();
    }

    public synchronized boolean hasFreshKeys() {
        return !isEmpty(imgKey) && !isEmpty(subKey) && keyLoadedAtDay == currentDay();
    }

    public synchronized String signToQuery(Map<String, String> params) {
        return signToQuery(params, System.currentTimeMillis() / 1000);
    }

    synchronized String signToQuery(Map<String, String> params, long timestampSeconds) {
        if (isEmpty(imgKey) || isEmpty(subKey)) {
            throw new IllegalStateException("WBI keys are not initialized");
        }
        params.put("wts", String.valueOf(timestampSeconds));
        List<String> keys = new ArrayList<>(params.keySet());
        Collections.sort(keys);

        StringBuilder query = new StringBuilder();
        for (String key : keys) {
            if (query.length() > 0) {
                query.append("&");
            }
            String value = params.get(key) == null ? "" : params.get(key).replaceAll("[!'()*]", "");
            query.append(encodeURIComponent(key))
                    .append("=")
                    .append(encodeURIComponent(value));
        }
        String wRid = md5(query + mixinKey(imgKey + subKey));
        query.append("&w_rid=").append(wRid);
        return query.toString();
    }

    static String mixinKey(String rawKey) {
        StringBuilder builder = new StringBuilder();
        for (int index : MIXIN_KEY_ENC_TAB) {
            if (index < rawKey.length()) {
                builder.append(rawKey.charAt(index));
            }
            if (builder.length() == 32) {
                break;
            }
        }
        return builder.toString();
    }

    static String encodeURIComponent(String value) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        StringBuilder encoded = new StringBuilder();
        for (byte b : bytes) {
            int c = b & 0xff;
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
                    || c == '-' || c == '_' || c == '.' || c == '~') {
                encoded.append((char) c);
            } else {
                encoded.append("%").append(String.format(Locale.US, "%02X", c));
            }
        }
        return encoded.toString();
    }

    static String md5(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] bytes = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder builder = new StringBuilder();
            for (byte b : bytes) {
                builder.append(String.format(Locale.US, "%02x", b & 0xff));
            }
            return builder.toString();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static String extractKey(String url) {
        if (isEmpty(url)) {
            return "";
        }
        int queryIndex = url.indexOf('?');
        if (queryIndex >= 0) {
            url = url.substring(0, queryIndex);
        }
        int fragmentIndex = url.indexOf('#');
        if (fragmentIndex >= 0) {
            url = url.substring(0, fragmentIndex);
        }
        int slash = url.lastIndexOf('/');
        String lastPathSegment = slash >= 0 ? url.substring(slash + 1) : url;
        if (isEmpty(lastPathSegment)) {
            return "";
        }
        int dot = lastPathSegment.indexOf('.');
        return dot > 0 ? lastPathSegment.substring(0, dot) : lastPathSegment;
    }

    private static boolean isEmpty(String value) {
        return value == null || value.isEmpty();
    }

    private static long currentDay() {
        return System.currentTimeMillis() / 86400000L;
    }
}
