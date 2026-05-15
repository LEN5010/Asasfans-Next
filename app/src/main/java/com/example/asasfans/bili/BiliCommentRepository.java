package com.example.asasfans.bili;

import java.io.IOException;

import okhttp3.HttpUrl;

public class BiliCommentRepository {
    private static final String REPLY_URL = "https://api.bilibili.com/x/v2/reply";
    public static final int COMMENT_TYPE_VIDEO = 1;
    public static final int PAGE_SIZE = 20;

    private final BiliApiClient apiClient;

    public BiliCommentRepository(BiliApiClient apiClient) {
        this.apiClient = apiClient;
    }

    public BiliModels.ReplyResponse getVideoReplies(long aid, int page, int sort) throws IOException {
        HttpUrl url = BiliApiClient.urlBuilder(REPLY_URL)
                .addQueryParameter("type", String.valueOf(COMMENT_TYPE_VIDEO))
                .addQueryParameter("oid", String.valueOf(aid))
                .addQueryParameter("pn", String.valueOf(page))
                .addQueryParameter("ps", String.valueOf(PAGE_SIZE))
                .addQueryParameter("sort", String.valueOf(sort))
                .addQueryParameter("nohot", "0")
                .build();
        BiliModels.ReplyResponse response = apiClient.get(url.toString(), BiliApiClient.BILI_REFERER, BiliModels.ReplyResponse.class);
        if (response == null || response.code != 0) {
            throw new BiliException(response == null ? -1 : response.code, response == null ? "评论区加载失败" : response.message);
        }
        return response;
    }
}
