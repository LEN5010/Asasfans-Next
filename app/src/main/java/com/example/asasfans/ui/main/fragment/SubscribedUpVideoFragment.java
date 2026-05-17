package com.example.asasfans.ui.main.fragment;

import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.widget.ImageView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.example.asasfans.R;
import com.example.asasfans.bili.BiliApiClient;
import com.example.asasfans.bili.BiliAuthRepository;
import com.example.asasfans.bili.BiliCredentialStore;
import com.example.asasfans.bili.BiliModels;
import com.example.asasfans.bili.BiliVideoRepository;
import com.example.asasfans.bili.WbiSigner;
import com.example.asasfans.data.AdvancedSearchDataBean;
import com.example.asasfans.data.DBOpenHelper;
import com.example.asasfans.data.VideoListRules;
import com.example.asasfans.ui.customcomponent.RecyclerViewDecoration;
import com.example.asasfans.ui.main.adapter.PubdateVideoAdapter;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SubscribedUpVideoFragment extends Fragment {
    private static final int PAGE_SIZE_PER_UP = 10;

    private final List<AdvancedSearchDataBean.DataBean.ResultBean> resultBeans = new ArrayList<>();
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private PubdateVideoAdapter pubdateVideoAdapter;
    private SwipeRefreshLayout refreshLayout;
    private RecyclerView recyclerView;
    private ImageView toTop;
    private BiliVideoRepository videoRepository;
    private int page = 1;
    private boolean isLoadingMore;
    private boolean hasMore = true;

    public static SubscribedUpVideoFragment newInstance() {
        return new SubscribedUpVideoFragment();
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_main, container, false);
        setupRepository();
        setupViews(view);
        loadVideos(true);
        return view;
    }

    private void setupRepository() {
        BiliCredentialStore credentialStore = new BiliCredentialStore(requireContext());
        BiliApiClient apiClient = new BiliApiClient(credentialStore);
        BiliAuthRepository authRepository = new BiliAuthRepository(apiClient, credentialStore);
        videoRepository = new BiliVideoRepository(apiClient, authRepository, new WbiSigner());
    }

    private void setupViews(View view) {
        Animation fadeIn = AnimationUtils.loadAnimation(getActivity(), R.anim.fadein);
        recyclerView = view.findViewById(R.id.recyclerview);
        refreshLayout = view.findViewById(R.id.refreshLayout);
        toTop = view.findViewById(R.id.to_top);

        refreshLayout.setColorSchemeResources(R.color.tab_text_normal, R.color.cardBlue, R.color.bella);
        refreshLayout.setProgressBackgroundColorSchemeResource(R.color.cardWhite);
        refreshLayout.setOnRefreshListener(() -> loadVideos(true));

        pubdateVideoAdapter = new PubdateVideoAdapter(getActivity(), resultBeans, resultBeans.size());
        recyclerView.setAdapter(pubdateVideoAdapter);
        LinearLayoutManager layoutManager = new LinearLayoutManager(getActivity(), LinearLayoutManager.VERTICAL, false);
        layoutManager.setInitialPrefetchItemCount(2);
        recyclerView.setLayoutManager(layoutManager);
        recyclerView.addItemDecoration(new RecyclerViewDecoration(12, 12));
        recyclerView.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrollStateChanged(@NonNull RecyclerView recyclerView, int newState) {
                super.onScrollStateChanged(recyclerView, newState);
                LinearLayoutManager manager = (LinearLayoutManager) recyclerView.getLayoutManager();
                if (manager == null) {
                    return;
                }
                int firstVisibleItemPosition = manager.findFirstVisibleItemPosition();
                if (newState == RecyclerView.SCROLL_STATE_IDLE) {
                    if (firstVisibleItemPosition == 0) {
                        toTop.setVisibility(View.GONE);
                    } else {
                        toTop.startAnimation(fadeIn);
                        toTop.setVisibility(View.VISIBLE);
                    }
                } else if (newState == RecyclerView.SCROLL_STATE_DRAGGING) {
                    toTop.setVisibility(View.GONE);
                }
            }

            @Override
            public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                LinearLayoutManager manager = (LinearLayoutManager) recyclerView.getLayoutManager();
                if (manager != null && dy > 0 && hasMore && !isLoadingMore
                        && manager.findLastVisibleItemPosition() >= manager.getItemCount() - 2) {
                    loadVideos(false);
                }
            }
        });
        toTop.setOnClickListener(v -> recyclerView.smoothScrollToPosition(0));
    }

    private void loadVideos(boolean reset) {
        if (isLoadingMore) {
            return;
        }
        isLoadingMore = true;
        refreshLayout.setRefreshing(true);
        if (reset) {
            page = 1;
            hasMore = true;
            resultBeans.clear();
            pubdateVideoAdapter.notifyDataSetChanged();
        }
        int loadingPage = page;
        executor.execute(() -> {
            try {
                List<SubscribedUp> subscribedUps = loadSubscribedUps();
                LoadResult loadResult = loadPage(subscribedUps, loadingPage);
                runOnUiThread(() -> bindLoadResult(loadResult, reset));
            } catch (Exception e) {
                runOnUiThread(() -> bindLoadError(e));
            }
        });
    }

    private LoadResult loadPage(List<SubscribedUp> subscribedUps, int loadingPage) throws Exception {
        LoadResult loadResult = new LoadResult();
        if (subscribedUps.isEmpty()) {
            return loadResult;
        }
        LocalBlockRules blockRules = loadLocalBlockRules();
        Set<String> existingBvids = new LinkedHashSet<>();
        for (AdvancedSearchDataBean.DataBean.ResultBean bean : resultBeans) {
            existingBvids.add(bean.getBvid());
        }
        for (SubscribedUp subscribedUp : subscribedUps) {
            if (VideoListRules.isCarolRelated(subscribedUp.mid, "", "", "", subscribedUp.name)) {
                continue;
            }
            BiliModels.SpaceArchiveResponse response = videoRepository.getUserArchiveVideos(subscribedUp.mid, loadingPage, PAGE_SIZE_PER_UP);
            List<AdvancedSearchDataBean.DataBean.ResultBean> videos = videoRepository.mapSpaceArchiveVideos(response);
            loadResult.rawCount += videos.size();
            for (AdvancedSearchDataBean.DataBean.ResultBean video : videos) {
                if (subscribedUp.face != null && !subscribedUp.face.isEmpty()) {
                    video.setFace(subscribedUp.face);
                }
                if (video.getName() == null || video.getName().isEmpty()) {
                    video.setName(subscribedUp.name);
                }
                if (existingBvids.add(video.getBvid()) && !isBlocked(video, blockRules)) {
                    loadResult.videos.add(video);
                }
            }
        }
        Collections.sort(loadResult.videos, (left, right) -> Integer.compare(right.getPubdate(), left.getPubdate()));
        return loadResult;
    }

    private void bindLoadResult(LoadResult loadResult, boolean reset) {
        if (!isAdded()) {
            return;
        }
        int start = resultBeans.size();
        resultBeans.addAll(loadResult.videos);
        pubdateVideoAdapter.notifyItemRangeInserted(start, loadResult.videos.size());
        refreshLayout.setRefreshing(false);
        isLoadingMore = false;
        if (loadResult.rawCount == 0) {
            hasMore = false;
            Toast.makeText(getActivity(), reset ? "暂无订阅UP视频" : "后面没有内容了~", Toast.LENGTH_SHORT).show();
        } else {
            page++;
            if (loadResult.videos.isEmpty()) {
                Toast.makeText(getActivity(), "这一页订阅视频都被屏蔽掉了哦", Toast.LENGTH_SHORT).show();
            }
        }
    }

    private void bindLoadError(Exception e) {
        if (!isAdded()) {
            return;
        }
        refreshLayout.setRefreshing(false);
        isLoadingMore = false;
        Toast.makeText(getActivity(), errorMessage(e), Toast.LENGTH_LONG).show();
    }

    private String errorMessage(Exception e) {
        String message = e == null ? null : e.getMessage();
        return message == null || message.trim().isEmpty() ? getString(R.string.bili_play_failed) : message;
    }

    private boolean isBlocked(AdvancedSearchDataBean.DataBean.ResultBean bean, LocalBlockRules blockRules) {
        return blockRules.blackBvids.contains(bean.getBvid())
                || blockRules.blackMids.contains(bean.getMid())
                || VideoListRules.matchesBlackWord(bean.getTitle(), bean.getDesc(), bean.getTag(), bean.getTname(), blockRules.blackWords)
                || VideoListRules.matchesBlackTag(bean.getTag(), blockRules.blackTags)
                || VideoListRules.isCarolRelated(bean.getMid(), bean.getTitle(), bean.getDesc(), bean.getTag(), bean.getName());
    }

    private List<SubscribedUp> loadSubscribedUps() {
        List<SubscribedUp> subscribedUps = new ArrayList<>();
        DBOpenHelper dbOpenHelper = new DBOpenHelper(requireContext(), "blackList.db", null, DBOpenHelper.DB_VERSION);
        SQLiteDatabase db = dbOpenHelper.getReadableDatabase();
        Cursor cursor = null;
        try {
            cursor = db.query("subscribedUp", null, null, null, null, null, "updatedAt desc");
            int midColumn = cursor.getColumnIndexOrThrow("mid");
            int nameColumn = cursor.getColumnIndexOrThrow("name");
            int faceColumn = cursor.getColumnIndexOrThrow("face");
            while (cursor.moveToNext()) {
                subscribedUps.add(new SubscribedUp(cursor.getLong(midColumn), cursor.getString(nameColumn), cursor.getString(faceColumn)));
            }
        } finally {
            if (cursor != null) {
                cursor.close();
            }
            db.close();
            dbOpenHelper.close();
        }
        return subscribedUps;
    }

    private LocalBlockRules loadLocalBlockRules() {
        LocalBlockRules rules = new LocalBlockRules();
        DBOpenHelper dbOpenHelper = new DBOpenHelper(requireContext(), "blackList.db", null, DBOpenHelper.DB_VERSION);
        SQLiteDatabase db = dbOpenHelper.getReadableDatabase();
        try {
            readStringSet(db, "blackWord", "word", rules.blackWords);
            readStringSet(db, "blackTag", "tag", rules.blackTags);
            readStringSet(db, "blackBvid", "bvid", rules.blackBvids);
            readLongSet(db, "blackMid", "mid", rules.blackMids);
        } finally {
            db.close();
            dbOpenHelper.close();
        }
        return rules;
    }

    private void readStringSet(SQLiteDatabase db, String table, String column, Set<String> target) {
        Cursor cursor = null;
        try {
            cursor = db.query(table, null, null, null, null, null, null);
            int columnIndex = cursor.getColumnIndexOrThrow(column);
            while (cursor.moveToNext()) {
                target.add(cursor.getString(columnIndex));
            }
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }

    private void readLongSet(SQLiteDatabase db, String table, String column, Set<Long> target) {
        Cursor cursor = null;
        try {
            cursor = db.query(table, null, null, null, null, null, null);
            int columnIndex = cursor.getColumnIndexOrThrow(column);
            while (cursor.moveToNext()) {
                target.add(cursor.getLong(columnIndex));
            }
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }

    private void runOnUiThread(Runnable runnable) {
        if (getActivity() != null) {
            getActivity().runOnUiThread(runnable);
        }
    }

    @Override
    public void onDetach() {
        if (pubdateVideoAdapter != null) {
            pubdateVideoAdapter.closeSQL();
        }
        executor.shutdownNow();
        super.onDetach();
    }

    private static class SubscribedUp {
        final long mid;
        final String name;
        final String face;

        SubscribedUp(long mid, String name, String face) {
            this.mid = mid;
            this.name = name == null ? "" : name;
            this.face = face == null ? "" : face;
        }
    }

    private static class LocalBlockRules {
        final Set<String> blackWords = new HashSet<>();
        final Set<String> blackTags = new HashSet<>();
        final Set<String> blackBvids = new HashSet<>();
        final Set<Long> blackMids = new HashSet<>();
    }

    private static class LoadResult {
        final List<AdvancedSearchDataBean.DataBean.ResultBean> videos = new ArrayList<>();
        int rawCount;
    }
}
