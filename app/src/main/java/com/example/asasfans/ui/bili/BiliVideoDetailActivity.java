package com.example.asasfans.ui.bili;

import android.content.Intent;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.OptIn;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.source.MergingMediaSource;
import androidx.media3.exoplayer.source.ProgressiveMediaSource;
import androidx.media3.ui.PlayerView;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.asasfans.R;
import com.example.asasfans.bili.BiliApiClient;
import com.example.asasfans.bili.BiliAuthRepository;
import com.example.asasfans.bili.BiliCommentRepository;
import com.example.asasfans.bili.BiliCredentialStore;
import com.example.asasfans.bili.BiliException;
import com.example.asasfans.bili.BiliModels;
import com.example.asasfans.bili.BiliVideoRepository;
import com.example.asasfans.bili.WbiSigner;
import com.example.asasfans.data.DBOpenHelper;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.appbar.MaterialToolbar;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class BiliVideoDetailActivity extends AppCompatActivity {
    public static final String EXTRA_BVID = "bvid";
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_COVER = "cover";
    public static final String EXTRA_OWNER = "owner";

    private final ExecutorService executor = Executors.newFixedThreadPool(3);
    private final int[] commentSortValues = new int[]{1, 0, 2};

    private String bvid;
    private TextView titleView;
    private TextView ownerView;
    private TextView descView;
    private TextView commentStatus;
    private MaterialButton subscribeButton;
    private Spinner pageSpinner;
    private Spinner qualitySpinner;
    private Spinner commentSortSpinner;
    private RecyclerView commentsRecycler;
    private BiliCommentAdapter commentAdapter;
    private BiliVideoRepository videoRepository;
    private BiliCommentRepository commentRepository;
    private BiliApiClient apiClient;
    private ExoPlayer player;
    private List<BiliModels.Page> pages = new ArrayList<>();
    private BiliModels.VideoViewData videoData;
    private int selectedPageIndex;
    private long aid;
    private int nextCommentPage = 1;
    private int commentSort = 1;
    private boolean commentsLoading;
    private boolean hasMoreComments = true;
    private boolean mp4FallbackTried;
    private long currentCid;
    private int selectedQn;
    private boolean bindingQualitySpinner;
    private BiliModels.Owner currentOwner;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_bili_video_detail);

        bvid = getIntent().getStringExtra(EXTRA_BVID);
        if (bvid == null || bvid.isEmpty()) {
            Toast.makeText(this, R.string.bili_play_failed, Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        setupRepositories();
        setupViews();
        setupPlayer();
        bindIntentPlaceholders();
        loadVideoDetail();
    }

    private void setupRepositories() {
        BiliCredentialStore credentialStore = new BiliCredentialStore(this);
        apiClient = new BiliApiClient(credentialStore);
        BiliAuthRepository authRepository = new BiliAuthRepository(apiClient, credentialStore);
        videoRepository = new BiliVideoRepository(apiClient, authRepository, new WbiSigner());
        commentRepository = new BiliCommentRepository(apiClient);
    }

    private void setupViews() {
        MaterialToolbar toolbar = findViewById(R.id.bili_detail_toolbar);
        toolbar.setNavigationOnClickListener(v -> finish());
        findViewById(R.id.bili_open_external).setOnClickListener(v -> openInBilibili());
        subscribeButton = findViewById(R.id.bili_subscribe_up);
        subscribeButton.setOnClickListener(v -> toggleOwnerSubscription());

        titleView = findViewById(R.id.bili_detail_title);
        ownerView = findViewById(R.id.bili_detail_owner);
        descView = findViewById(R.id.bili_detail_desc);
        pageSpinner = findViewById(R.id.bili_page_spinner);
        qualitySpinner = findViewById(R.id.bili_quality_spinner);
        commentSortSpinner = findViewById(R.id.bili_comment_sort_spinner);
        commentStatus = findViewById(R.id.bili_comment_status);
        commentsRecycler = findViewById(R.id.bili_comments_recycler);
        commentAdapter = new BiliCommentAdapter(this);
        commentsRecycler.setLayoutManager(new LinearLayoutManager(this));
        commentsRecycler.setAdapter(commentAdapter);
        commentsRecycler.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                if (dy > 0 && hasMoreComments && !commentsLoading && !recyclerView.canScrollVertically(1)) {
                    loadComments(false);
                }
            }
        });

        ArrayAdapter<String> sortAdapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item,
                new String[]{"按热度", "按时间", "按回复"});
        sortAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        commentSortSpinner.setAdapter(sortAdapter);
        commentSortSpinner.setSelection(0, false);
        commentSortSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                commentSort = commentSortValues[position];
                if (aid > 0) {
                    loadComments(true);
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
    }

    @OptIn(markerClass = UnstableApi.class)
    private void setupPlayer() {
        PlayerView playerView = findViewById(R.id.player_view);
        player = new ExoPlayer.Builder(this).build();
        playerView.setPlayer(player);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlayerError(PlaybackException error) {
                if (!mp4FallbackTried && currentCid > 0) {
                    Toast.makeText(BiliVideoDetailActivity.this, R.string.bili_play_mp4_fallback, Toast.LENGTH_SHORT).show();
                    fallbackToMp4(currentCid);
                } else {
                    Toast.makeText(BiliVideoDetailActivity.this, R.string.bili_play_failed, Toast.LENGTH_SHORT).show();
                }
            }
        });
    }

    private void bindIntentPlaceholders() {
        String title = getIntent().getStringExtra(EXTRA_TITLE);
        String owner = getIntent().getStringExtra(EXTRA_OWNER);
        titleView.setText(title == null ? "" : title);
        ownerView.setText(owner == null ? "" : owner);
        descView.setText("");
        commentStatus.setText(R.string.bili_comments_loading);
    }

    private void loadVideoDetail() {
        executor.execute(() -> {
            try {
                BiliModels.VideoViewResponse response = videoRepository.getVideoView(bvid);
                runOnUiIfAlive(() -> bindVideoDetail(response.data));
            } catch (Exception e) {
                runOnUiIfAlive(() -> {
                    String message = errorMessage(e, R.string.bili_play_failed);
                    commentStatus.setText(message);
                    Toast.makeText(this, message, Toast.LENGTH_LONG).show();
                });
            }
        });
    }

    private void bindVideoDetail(BiliModels.VideoViewData data) {
        if (data == null) {
            commentStatus.setText(R.string.bili_play_failed);
            return;
        }
        videoData = data;
        aid = data.aid;
        titleView.setText(data.title == null ? "" : data.title);
        ownerView.setText(data.owner == null ? "" : data.owner.name);
        currentOwner = data.owner;
        bindSubscribeButton();
        descView.setText(data.desc == null ? "" : data.desc);
        pages = data.pages == null ? new ArrayList<>() : data.pages;
        selectedPageIndex = 0;
        setupPageSpinner();
        loadSelectedPage();
        loadComments(true);
    }

    private void setupPageSpinner() {
        List<String> pageNames = new ArrayList<>();
        if (pages.isEmpty()) {
            pageNames.add("P1");
        } else {
            for (BiliModels.Page page : pages) {
                String part = page.part == null || page.part.isEmpty() ? ("P" + page.page) : page.part;
                pageNames.add("P" + page.page + " " + part);
            }
        }
        pageSpinner.setOnItemSelectedListener(null);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, pageNames);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        pageSpinner.setAdapter(adapter);
        pageSpinner.setSelection(0, false);
        pageSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (position == selectedPageIndex) {
                    return;
                }
                selectedPageIndex = position;
                loadSelectedPage();
                loadComments(true);
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
    }

    private void loadSelectedPage() {
        currentCid = getSelectedCid();
        selectedQn = 0;
        mp4FallbackTried = false;
        if (currentCid <= 0) {
            Toast.makeText(this, R.string.bili_play_failed, Toast.LENGTH_SHORT).show();
            return;
        }
        bindQualityOptions(new ArrayList<>());
        loadDashPlayback(currentCid, true);
    }

    private long getSelectedCid() {
        if (!pages.isEmpty() && selectedPageIndex >= 0 && selectedPageIndex < pages.size()) {
            return pages.get(selectedPageIndex).cid;
        }
        return videoData == null ? 0 : videoData.cid;
    }

    private void loadDashPlayback(long cid, boolean refreshQualityOptions) {
        executor.execute(() -> {
            try {
                BiliModels.PlayUrlResponse playUrl = videoRepository.getDashPlayUrl(bvid, cid, selectedQn);
                String videoUrl = videoRepository.pickDashVideoUrl(playUrl, selectedQn);
                String audioUrl = videoRepository.pickDashAudioUrl(playUrl);
                if (videoUrl.isEmpty() || audioUrl.isEmpty()) {
                    throw new BiliException(-1, getString(R.string.bili_play_failed));
                }
                runOnUiIfAlive(() -> {
                    if (refreshQualityOptions) {
                        bindQualityOptions(videoRepository.buildQualityOptions(playUrl));
                    }
                    playDash(videoUrl, audioUrl);
                });
            } catch (Exception e) {
                runOnUiIfAlive(() -> fallbackToMp4(cid));
            }
        });
    }

    private void bindQualityOptions(List<BiliModels.VideoQuality> qualities) {
        List<BiliModels.VideoQuality> displayQualities = qualities == null || qualities.isEmpty()
                ? new ArrayList<>()
                : new ArrayList<>(qualities);
        if (displayQualities.isEmpty()) {
            displayQualities.add(new BiliModels.VideoQuality(0, "自动", true));
        }
        bindingQualitySpinner = true;
        qualitySpinner.setOnItemSelectedListener(null);
        ArrayAdapter<BiliModels.VideoQuality> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, displayQualities);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        qualitySpinner.setAdapter(adapter);
        qualitySpinner.setSelection(0, false);
        qualitySpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (bindingQualitySpinner) {
                    return;
                }
                BiliModels.VideoQuality quality = (BiliModels.VideoQuality) parent.getItemAtPosition(position);
                selectedQn = quality.qn;
                mp4FallbackTried = false;
                if (currentCid > 0) {
                    loadDashPlayback(currentCid, false);
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        bindingQualitySpinner = false;
    }

    @OptIn(markerClass = UnstableApi.class)
    private void playDash(String videoUrl, String audioUrl) {
        mp4FallbackTried = false;
        OkHttpDataSource.Factory factory = apiClient.newMediaDataSourceFactory(BiliVideoRepository.videoReferer(bvid));
        MediaSource videoSource = new ProgressiveMediaSource.Factory(factory)
                .createMediaSource(MediaItem.fromUri(videoUrl));
        MediaSource audioSource = new ProgressiveMediaSource.Factory(factory)
                .createMediaSource(MediaItem.fromUri(audioUrl));
        player.setMediaSource(new MergingMediaSource(videoSource, audioSource));
        player.prepare();
        player.play();
    }

    private void fallbackToMp4(long cid) {
        mp4FallbackTried = true;
        executor.execute(() -> {
            try {
                BiliModels.PlayUrlResponse playUrl = videoRepository.getMp4PlayUrl(bvid, cid, selectedQn);
                String mp4Url = videoRepository.pickMp4Url(playUrl);
                if (mp4Url.isEmpty()) {
                    throw new BiliException(-1, getString(R.string.bili_play_failed));
                }
                runOnUiIfAlive(() -> playMp4(mp4Url));
            } catch (Exception e) {
                runOnUiIfAlive(() -> Toast.makeText(this, errorMessage(e, R.string.bili_play_failed), Toast.LENGTH_LONG).show());
            }
        });
    }

    @OptIn(markerClass = UnstableApi.class)
    private void playMp4(String url) {
        OkHttpDataSource.Factory factory = apiClient.newMediaDataSourceFactory(BiliVideoRepository.videoReferer(bvid));
        MediaSource mediaSource = new ProgressiveMediaSource.Factory(factory)
                .createMediaSource(MediaItem.fromUri(url));
        player.setMediaSource(mediaSource);
        player.prepare();
        player.play();
    }

    private void loadComments(boolean reset) {
        if (aid <= 0 || commentsLoading) {
            return;
        }
        if (reset) {
            nextCommentPage = 1;
            hasMoreComments = true;
            commentAdapter.setReplies(null);
        }
        commentsLoading = true;
        commentStatus.setText(nextCommentPage == 1 ? R.string.bili_comments_loading : R.string.bili_comments_load_more);
        int page = nextCommentPage;
        int sort = commentSort;
        executor.execute(() -> {
            try {
                BiliModels.ReplyResponse response = commentRepository.getVideoReplies(aid, page, sort);
                List<BiliModels.Reply> replies = response.data == null ? null : response.data.replies;
                runOnUiIfAlive(() -> bindComments(replies, reset, page, response.data == null ? null : response.data.page));
            } catch (Exception e) {
                runOnUiIfAlive(() -> bindCommentError(e));
            }
        });
    }

    private void bindComments(List<BiliModels.Reply> replies, boolean reset, int loadedPage, BiliModels.ReplyPage pageInfo) {
        commentsLoading = false;
        if (reset) {
            commentAdapter.setReplies(replies);
        } else {
            commentAdapter.addReplies(replies);
        }
        int loaded = replies == null ? 0 : replies.size();
        nextCommentPage = loadedPage + 1;
        hasMoreComments = loaded >= BiliCommentRepository.PAGE_SIZE
                && (pageInfo == null || commentAdapter.getReplyCount() < pageInfo.count);
        if (commentAdapter.getReplyCount() == 0) {
            commentStatus.setText(R.string.bili_comments_empty);
        } else {
            commentStatus.setText("评论 " + commentAdapter.getReplyCount() + (pageInfo == null ? "" : "/" + pageInfo.count));
        }
    }

    private void bindCommentError(Exception e) {
        commentsLoading = false;
        if (e instanceof BiliException && ((BiliException) e).getCode() == 12002) {
            commentStatus.setText(R.string.bili_comments_closed);
        } else {
            commentStatus.setText(errorMessage(e, R.string.bili_play_failed));
        }
    }

    private void runOnUiIfAlive(Runnable runnable) {
        runOnUiThread(() -> {
            if (!isFinishing() && !isDestroyed()) {
                runnable.run();
            }
        });
    }

    private String errorMessage(Exception e, int fallbackResId) {
        String message = e == null ? null : e.getMessage();
        return message == null || message.trim().isEmpty() ? getString(fallbackResId) : message;
    }

    private void openInBilibili() {
        try {
            Intent appIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("bilibili://video/" + bvid));
            startActivity(appIntent);
        } catch (Exception e) {
            try {
                Intent webIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(BiliVideoRepository.videoReferer(bvid)));
                startActivity(webIntent);
            } catch (Exception ignored) {
                Toast.makeText(this, R.string.bili_open_failed, Toast.LENGTH_SHORT).show();
            }
        }
    }

    private void bindSubscribeButton() {
        if (currentOwner == null || currentOwner.mid <= 0) {
            subscribeButton.setVisibility(View.GONE);
            return;
        }
        subscribeButton.setVisibility(View.VISIBLE);
        subscribeButton.setText(isOwnerSubscribed(currentOwner.mid) ? R.string.unsubscribe_this_up : R.string.subscribe_this_up);
    }

    private void toggleOwnerSubscription() {
        if (currentOwner == null || currentOwner.mid <= 0) {
            return;
        }
        if (isOwnerSubscribed(currentOwner.mid)) {
            unsubscribeOwner(currentOwner.mid);
            Toast.makeText(this, R.string.unsubscribe_this_up, Toast.LENGTH_SHORT).show();
        } else {
            subscribeOwner(currentOwner);
            Toast.makeText(this, R.string.subscribe_this_up, Toast.LENGTH_SHORT).show();
        }
        bindSubscribeButton();
    }

    private boolean isOwnerSubscribed(long mid) {
        DBOpenHelper dbOpenHelper = new DBOpenHelper(this, "blackList.db", null, DBOpenHelper.DB_VERSION);
        SQLiteDatabase db = dbOpenHelper.getReadableDatabase();
        Cursor cursor = null;
        try {
            cursor = db.query("subscribedUp", null, "mid=?", new String[]{String.valueOf(mid)}, null, null, null);
            return cursor.moveToFirst();
        } finally {
            if (cursor != null) {
                cursor.close();
            }
            db.close();
            dbOpenHelper.close();
        }
    }

    private void subscribeOwner(BiliModels.Owner owner) {
        DBOpenHelper dbOpenHelper = new DBOpenHelper(this, "blackList.db", null, DBOpenHelper.DB_VERSION);
        SQLiteDatabase db = dbOpenHelper.getWritableDatabase();
        try {
            ContentValues values = new ContentValues();
            values.put("mid", owner.mid);
            values.put("name", owner.name == null ? "" : owner.name);
            values.put("face", owner.face == null ? "" : owner.face);
            values.put("note", "");
            values.put("updatedAt", System.currentTimeMillis() / 1000);
            db.insertWithOnConflict("subscribedUp", null, values, SQLiteDatabase.CONFLICT_REPLACE);
        } finally {
            db.close();
            dbOpenHelper.close();
        }
    }

    private void unsubscribeOwner(long mid) {
        DBOpenHelper dbOpenHelper = new DBOpenHelper(this, "blackList.db", null, DBOpenHelper.DB_VERSION);
        SQLiteDatabase db = dbOpenHelper.getWritableDatabase();
        try {
            db.delete("subscribedUp", "mid=?", new String[]{String.valueOf(mid)});
        } finally {
            db.close();
            dbOpenHelper.close();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (player != null) {
            player.pause();
        }
    }

    @Override
    protected void onDestroy() {
        executor.shutdownNow();
        if (player != null) {
            player.release();
            player = null;
        }
        super.onDestroy();
    }
}
