package com.example.asasfans.bili;

import com.google.gson.annotations.SerializedName;

import java.util.List;

public class BiliModels {
    public static class BaseResponse {
        public int code;
        public String message;
        public int ttl;

        public boolean isSuccess() {
            return code == 0;
        }
    }

    public static class QrGenerateResponse extends BaseResponse {
        public QrGenerateData data;
    }

    public static class QrGenerateData {
        public String url;
        @SerializedName("qrcode_key")
        public String qrcodeKey;
    }

    public static class QrPollResponse extends BaseResponse {
        public QrPollData data;
    }

    public static class QrPollData {
        public String url;
        @SerializedName("refresh_token")
        public String refreshToken;
        public long timestamp;
        public int code;
        public String message;
    }

    public static class NavResponse extends BaseResponse {
        public NavData data;
    }

    public static class NavData {
        public boolean isLogin;
        public long mid;
        public String uname;
        public String face;
        @SerializedName("wbi_img")
        public WbiImage wbiImg;
    }

    public static class WbiImage {
        @SerializedName("img_url")
        public String imgUrl;
        @SerializedName("sub_url")
        public String subUrl;
    }

    public static class VideoViewResponse extends BaseResponse {
        public VideoViewData data;
    }

    public static class VideoViewData {
        public String bvid;
        public long aid;
        public int videos;
        public String title;
        public String desc;
        public String pic;
        public long cid;
        public int duration;
        public Owner owner;
        public Stat stat;
        public List<Page> pages;
    }

    public static class Owner {
        public long mid;
        public String name;
        public String face;
    }

    public static class Stat {
        public int view;
        public int danmaku;
        public int reply;
        public int favorite;
        public int coin;
        public int share;
        public int like;
    }

    public static class Page {
        public long cid;
        public int page;
        public String part;
        public int duration;
    }

    public static class PlayUrlResponse extends BaseResponse {
        public PlayUrlData data;
    }

    public static class PlayUrlData {
        public int quality;
        public String format;
        public long timelength;
        public List<Durl> durl;
        public Dash dash;
        @SerializedName("accept_description")
        public List<String> acceptDescription;
        @SerializedName("accept_quality")
        public List<Integer> acceptQuality;
    }

    public static class Durl {
        public int order;
        public long length;
        public long size;
        public String url;
        @SerializedName("backup_url")
        public List<String> backupUrl;
    }

    public static class Dash {
        public List<DashMedia> video;
        public List<DashMedia> audio;
    }

    public static class DashMedia {
        public int id;
        @SerializedName(value = "baseUrl", alternate = {"base_url"})
        public String baseUrl;
        @SerializedName(value = "backupUrl", alternate = {"backup_url"})
        public List<String> backupUrl;
        public String codecs;
        public int bandwidth;
    }

    public static class VideoQuality {
        public final int qn;
        public final String description;
        public final boolean auto;

        public VideoQuality(int qn, String description, boolean auto) {
            this.qn = qn;
            this.description = description;
            this.auto = auto;
        }

        @Override
        public String toString() {
            return description;
        }
    }

    public static class ReplyResponse extends BaseResponse {
        public ReplyData data;
    }

    public static class ReplyData {
        public ReplyPage page;
        public List<Reply> replies;
        public List<Reply> hots;
        public ReplyControl control;
    }

    public static class ReplyPage {
        public int num;
        public int size;
        public int count;
        public int acount;
    }

    public static class ReplyControl {
        @SerializedName("input_disable")
        public boolean inputDisable;
        @SerializedName("root_input_text")
        public String rootInputText;
        @SerializedName("bg_text")
        public String bgText;
    }

    public static class Reply {
        public long rpid;
        public long oid;
        public long mid;
        public long root;
        public long parent;
        public int count;
        public int rcount;
        public long ctime;
        public int like;
        public int action;
        public ReplyMember member;
        public ReplyContent content;
        public List<Reply> replies;
    }

    public static class ReplyMember {
        public String mid;
        public String uname;
        public String avatar;
    }

    public static class ReplyContent {
        public String message;
    }
}
