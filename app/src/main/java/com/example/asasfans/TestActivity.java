package com.example.asasfans;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.RotateAnimation;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.view.GravityCompat;
import androidx.drawerlayout.widget.DrawerLayout;
import androidx.fragment.app.Fragment;
import androidx.viewpager2.widget.ViewPager2;

import com.example.asasfans.data.GithubVersionBean;
import com.example.asasfans.data.TabData;
import com.example.asasfans.ui.main.ConfigActivity;
import com.example.asasfans.ui.main.adapter.NewBottomPagerAdapter;
import com.example.asasfans.ui.main.fragment.NewToolsFragment;
import com.example.asasfans.ui.main.fragment.WebFragment;
import com.example.asasfans.util.ACache;
import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.navigation.NavigationView;
import com.google.android.material.tabs.TabLayout;
import com.google.gson.Gson;
import com.orhanobut.dialogplus.DialogPlus;
import com.orhanobut.dialogplus.ViewHolder;

import com.tencent.smtt.export.external.TbsCoreSettings;
import com.tencent.smtt.sdk.QbSdk;
import com.yy.floatserver.FloatClient;
import com.yy.floatserver.FloatHelper;
import com.yy.floatserver.IFloatPermissionCallback;


import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * @author akarinini
 * @description 测试用页面，目前作为主页面
 *              2022/3/03 修改底部导航栏可以动态改变标签
 *              2022/3/7 更新了图片加载方式。之前是自己写的一个根据url加载图片的imageview，
 *                       问题在于它把全部的图片放在了内存中，浏览几百个视频就oom然后crash掉了，
 *                       现在换成了开源库imageloader，它的方式是把图片下载到存储里，
 *                       遇到相同的url直接从存储中加载。
 *                       修改了预加载页面数量，全部预加载。
 *              2022/4/10 固定了页面
 */

public class TestActivity extends AppCompatActivity {
    /** 上次点击返回键的时间 */
    private long lastBackPressed;
    /** 两次点击的间隔时间 */
    private static final int QUIT_INTERVAL = 3000;

    private TabLayout tabs;
    public static ViewPager2 viewPager;
    public List<TabData> mFragmentList = new ArrayList<>();

    private Object mCurrentFragment;

    private SharedPreferences userInfo;
    private SharedPreferences.Editor editor;//获取Editor
    private Map<String, ?> tmp;
    private DialogPlus dialog;
    private View dialogView;

    private DrawerLayout drawerLayout;
    private NavigationView navigationView;
    private MaterialToolbar topAppBar;

    private Handler mHandler = new Handler();

    private NewBottomPagerAdapter newBottomPagerAdapter;

    public static FloatHelper floatHelper;
    /*
    权限相关
     */
    public String[] permissions = new String[]{
            Manifest.permission.INTERNET,
            Manifest.permission.ACCESS_NETWORK_STATE,
            Manifest.permission.SYSTEM_ALERT_WINDOW,
            Manifest.permission.REORDER_TASKS,
            Manifest.permission.BLUETOOTH,
            Manifest.permission.WAKE_LOCK
    };
    List<String> mPermissionList = new ArrayList<>();
    private static final int PERMISSION_REQUEST = 1;
    private static final int REQUEST_DIALOG_PERMISSION = 2;

    public static Context contextTestActivity;

    //试图解决锁屏后wlan休眠的问题，无效，寄了
    private PowerManager pm;

    private PowerManager.WakeLock wl;

    // 定义WifiManager对象
    private WifiManager wifiManager;

    // 定义一个WifiLock
    private WifiManager.WifiLock wifiLock;
//    private static HttpProxyCacheServer proxy;

    @Override
    protected void onResume() {
        super.onResume();
        floatHelper.dismiss();
    }

    @Override
    protected void onPause() {
        super.onPause();
        ACache aCache = ACache.get(this);
        String tmpACache =  aCache.getAsString("isShowFloatingBall"); // yes or no
        if (tmpACache == null){
            floatHelper.show();
//            Toast.makeText(TestActivity.this, "悬浮球默认打开哦，可以在设置关闭", Toast.LENGTH_SHORT).show();
        }else if (tmpACache.equals("yes")){
            floatHelper.show();
        }else if (tmpACache.equals("no")){

        }
    }

    @SuppressLint("InvalidWakeLockTag")
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.new_activity_bottom_main);
        contextTestActivity = TestActivity.this;
        checkPermission();

        pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        wl = pm.newWakeLock(PowerManager.SCREEN_DIM_WAKE_LOCK, "POWER_MANAGER_TAG");
        wl.acquire();
        wifiManager = (WifiManager) contextTestActivity.getSystemService(Context.WIFI_SERVICE);
        wifiLock = wifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "WifiLocKManager");
        wifiLock.acquire();
        initFloatingBall(TestActivity.this);

//        setContentView(R.layout.activity_bottom_main);
//
//        //恢复时会第二次添加底部导航栏
//        mFragmentList.clear();
//        initTab();
//
//
//        bottomPagerAdapter = new BottomPagerAdapter(this, getSupportFragmentManager(), mFragmentList);
//        mCurrentFragment = bottomPagerAdapter.getCurrentFragment();
//        viewPager = findViewById(R.id.view_pager_main);
//        viewPager.setAdapter(bottomPagerAdapter);
//        viewPager.setOffscreenPageLimit(4);
//        tabs = findViewById(R.id.tabs_bottom);
//        tabs.setupWithViewPager(viewPager);
        drawerLayout = findViewById(R.id.drawer_layout);
        navigationView = findViewById(R.id.nav_view);
        topAppBar = findViewById(R.id.top_app_bar);
        configureTopAppBar();

        newBottomPagerAdapter = new NewBottomPagerAdapter(this);
        viewPager = findViewById(R.id.vp_content);
        viewPager.setAdapter(newBottomPagerAdapter);
        viewPager.setOffscreenPageLimit(3);
        viewPager.setUserInputEnabled(false);
        configureDrawerNavigation();

        viewPager.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
            @Override
            public void onPageSelected(int position) {
                super.onPageSelected(position);
                updateNavigationState(position);
            }
        });

        //设置分割线
//        LinearLayout linearLayout = (LinearLayout) tabs.getChildAt(0);
//        linearLayout.setShowDividers(LinearLayout.SHOW_DIVIDER_MIDDLE);
//        linearLayout.setDividerDrawable(ContextCompat.getDrawable(this,
//                R.drawable.divider)); //设置分割线的样式
//        linearLayout.setDividerPadding(20); //设置分割线间隔

        Intent intent = getIntent();
        Bundle bundle = intent.getExtras();
        Gson gson = new Gson();
        if (bundle == null){

        } else if (bundle.getString("latestVersion").equals("")){
            Toast.makeText(TestActivity.this, "网络错误，版本号获取失败", Toast.LENGTH_SHORT).show();
        }else {
            if (bundle.getString("latestVersion").startsWith("{\"url\"")){
                GithubVersionBean githubVersionBean = gson.fromJson(bundle.getString("latestVersion"), GithubVersionBean.class);
                String versionName = githubVersionBean.getTag_name();

                String[] tmp3 = versionName.split("v");
                String[] versionCodeString = tmp3[1].split("\\.");
                int versionCode = Integer.valueOf(versionCodeString[0]) * 100 + Integer.valueOf(versionCodeString[1]) * 10 + Integer.valueOf(versionCodeString[2]) * 1;
                if (versionCode > getVersionCode(TestActivity.this)) {
                    initDialog(TestActivity.this);
                    TextView title = dialogView.findViewById(R.id.title);
                    TextView content = dialogView.findViewById(R.id.upgrade_content);
                    TextView cancel = dialogView.findViewById(R.id.close);
                    TextView confirm = dialogView.findViewById(R.id.upgrade);

                    content.setText(githubVersionBean.getBody());

                    confirm.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://fan.asoul.us.kg"));
                            startActivity(intent);
                            dialog.dismiss();
                        }
                    });
                    cancel.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            dialog.dismiss();
                        }
                    });
                    dialog.show();
                }
            }
        }
        selectPage(0);

    }

//    public static void init(Context aContext) {
//        //设置点击栏目知想打开的页面
//        RxConstants.CLASSNAME = "MainActivty";
//
//        RxDownloadManager manager = RxDownloadManager.getInstance();
//        manager.init(aContext, new DownloadAdapter());
//        manager.setContext(aContext);
//        manager.setListener(new DLDownloadListener(aContext));
//        DLNormalCallback normalCallback = new DLNormalCallback();
//        if (manager.getClient() != null) {
//            manager.getClient().setCallback(normalCallback);
//        }
//        RxDownLoadCenter.getInstance(aContext).loadTask();
//    }
    private void configureTopAppBar() {
        int statusBarHeight = AsApplication.Companion.getStatusBarHeight();
        ViewGroup.LayoutParams layoutParams = topAppBar.getLayoutParams();
        layoutParams.height = (int) (56 * getResources().getDisplayMetrics().density) + statusBarHeight;
        topAppBar.setLayoutParams(layoutParams);
        topAppBar.setPadding(topAppBar.getPaddingLeft(), statusBarHeight, topAppBar.getPaddingRight(), topAppBar.getPaddingBottom());
        topAppBar.setNavigationOnClickListener(v -> drawerLayout.openDrawer(GravityCompat.START));
    }

    private void configureDrawerNavigation() {
        navigationView.setCheckedItem(R.id.nav_video);
        navigationView.setNavigationItemSelectedListener(item -> {
            int itemId = item.getItemId();
            if (itemId == R.id.nav_video) {
                selectPage(0);
            } else if (itemId == R.id.nav_music) {
                selectPage(1);
            } else if (itemId == R.id.nav_tools) {
                selectPage(2);
            } else if (itemId == R.id.nav_calendar) {
                selectPage(3);
            } else if (itemId == R.id.nav_settings) {
                drawerLayout.closeDrawer(GravityCompat.START);
                startActivity(new Intent(TestActivity.this, ConfigActivity.class));
                return false;
            }
            drawerLayout.closeDrawer(GravityCompat.START);
            return true;
        });
    }

    private void selectPage(int position) {
        viewPager.setCurrentItem(position, false);
        updateNavigationState(position);
    }

    private void updateNavigationState(int position) {
        if (position == 0) {
            navigationView.setCheckedItem(R.id.nav_video);
            topAppBar.setTitle(R.string.nav_video);
        } else if (position == 1) {
            navigationView.setCheckedItem(R.id.nav_music);
            topAppBar.setTitle(R.string.nav_music);
        } else if (position == 2) {
            navigationView.setCheckedItem(R.id.nav_tools);
            topAppBar.setTitle(R.string.nav_tools);
        } else if (position == 3) {
            navigationView.setCheckedItem(R.id.nav_calendar);
            topAppBar.setTitle(R.string.nav_calendar);
        }
    }

//    public static HttpProxyCacheServer getProxy() {
//
////        App app = (App) context.getApplicationContext();
//        return proxy == null ? (proxy = newProxy()) : proxy;
//    }
//    private static HttpProxyCacheServer newProxy() {
//        return new HttpProxyCacheServer.Builder(contextTestActivity)
//                .maxCacheSize(6 * 1024 * 1024)       // 1 Gb for cache
//                .build();
//    }
    private void initDialog(Context context){
        dialog = DialogPlus.newDialog(context)
                .setContentHolder(new ViewHolder(R.layout.dialog_upgrade))
                .setContentHeight(ViewGroup.LayoutParams.WRAP_CONTENT)
                .setContentWidth(ViewGroup.LayoutParams.MATCH_PARENT)
                .setCancelable(true)
                .setGravity(Gravity.CENTER)
                .setContentBackgroundResource(R.color.transparent)
                .create();
        dialogView = dialog.getHolderView();
    }

    private void initX5(){
//        QbSdk.setDownloadWithoutWifi(true);
        QbSdk.initX5Environment(contextTestActivity, new QbSdk.PreInitCallback() {
            @Override
            public void onCoreInitFinished() {
                // 内核初始化完成，可能为系统内核，也可能为系统内核
            }

            /**
             * 预初始化结束
             * 由于X5内核体积较大，需要依赖网络动态下发，所以当内核不存在的时候，默认会回调false，此时将会使用系统内核代替
             * @param isX5 是否使用X5内核
             */
            @Override
            public void onViewInitFinished(boolean isX5) {

            }
        });
        HashMap map = new HashMap();
        map.put(TbsCoreSettings.TBS_SETTINGS_USE_SPEEDY_CLASSLOADER, true);
        map.put(TbsCoreSettings.TBS_SETTINGS_USE_DEXLOADER_SERVICE, true);
        QbSdk.initTbsSettings(map);
    }


    public void initFloatingBall(Context context){
        View view =  LayoutInflater.from(contextTestActivity).inflate(R.layout.view_floating_ball, null);
        floatHelper = new FloatClient.Builder()
                .with(contextTestActivity)
                .addView(view)
                .enableDefaultPermissionDialog(false)
                .setClickTarget(TestActivity.class)
                .addPermissionCallback(new IFloatPermissionCallback() {
                    @Override
                    public void onPermissionResult(boolean b) {
                        if (!b){
                            ACache aCache = ACache.get(context);
                            String isNoLongerShowFloatingBall =  aCache.getAsString("isNoLongerShowFloatingBall"); // yes or no
                            DialogPlus dialogP = DialogPlus.newDialog(context)
                                    .setContentHolder(new ViewHolder(R.layout.my_dialog))
                                    .setContentHeight(ViewGroup.LayoutParams.WRAP_CONTENT)
                                    .setContentWidth(ViewGroup.LayoutParams.MATCH_PARENT)
                                    .setGravity(Gravity.CENTER)
                                    .setContentBackgroundResource(R.color.transparent)
                                    .create();;
                            View dialogViewP = dialogP.getHolderView();
                            TextView title = dialogViewP.findViewById(R.id.dialog_title);
                            TextView content = dialogViewP.findViewById(R.id.dialog_content);
                            TextView confirm = dialogViewP.findViewById(R.id.confirm);
                            TextView cancel = dialogViewP.findViewById(R.id.cancel);
                            title.setText("需要悬浮窗权限");
                            content.setText("通过悬浮球可以在其他应用快速回到AsAsFans，需要去开启悬浮窗权限，悬浮窗只会在其他界面显示出来哦");
                            confirm.setText("去开启");
                            cancel.setText("不再提醒");
                            cancel.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    aCache.put("isNoLongerShowFloatingBall", "yes");
                                    dialogP.dismiss();
                                }
                            });
                            confirm.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    int sdkInt = Build.VERSION.SDK_INT;
                                    if (sdkInt >= Build.VERSION_CODES.O) {//8.0以上
                                        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
                                        startActivityForResult(intent, REQUEST_DIALOG_PERMISSION);
                                    } else if (sdkInt >= Build.VERSION_CODES.M) {//6.0-8.0
                                        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
                                        intent.setData(Uri.parse("package:" + getPackageName()));
                                        startActivityForResult(intent, REQUEST_DIALOG_PERMISSION);
                                    } else {//4.4-6.0一下
                                        //无需处理了
                                    }
                                    dialogP.dismiss();
                                }
                            });
                            if (isNoLongerShowFloatingBall == null){
                                dialogP.show();
                            }else if (isNoLongerShowFloatingBall.equals("yes")){
                                aCache.put("isShowFloatingBall", "no");
                            }else if (isNoLongerShowFloatingBall.equals("no")){
                                dialogP.show();
                            }
                        }
                    }
                })
                .build();
        ACache aCache = ACache.get(this);
        String tmpACache =  aCache.getAsString("isShowFloatingBall"); // yes or no
        if (tmpACache == null){
            floatHelper.show();
//            Toast.makeText(TestActivity.this, "悬浮球默认打开哦，可以在设置关闭", Toast.LENGTH_SHORT).show();
        }else if (tmpACache.equals("yes")){
            floatHelper.show();
        }else if (tmpACache.equals("no")){

        }
    }


    private void initVideoDownloader(){


    }

    public static int getVersionCode(Context mContext) {
        int versionCode = 0;
        try {
                //获取软件版本号，对应AndroidManifest.xml下android:versionCode
                versionCode = mContext.getPackageManager().
                getPackageInfo(mContext.getPackageName(), 0).versionCode;
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }
        return versionCode;
    }


    /**
     * @description Override实现两次退出
     * @author akari
     * @time 2022/2/27 11:47
     */
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (drawerLayout != null && drawerLayout.isDrawerOpen(GravityCompat.START)) {
            drawerLayout.closeDrawer(GravityCompat.START);
            return true;
        }

        mCurrentFragment = getCurrentFragment();

        Log.i("instanceof", String.valueOf(mCurrentFragment instanceof WebFragment));
        Log.i("keyCode", String.valueOf(keyCode));
        //解决音量键的监听被webview劫持无法使用的问题
        if (!(keyCode==KeyEvent.KEYCODE_BACK)){
            return super.onKeyDown(keyCode, event);
        }
        if(mCurrentFragment instanceof WebFragment){
            ((WebFragment)mCurrentFragment).onKeyDown(keyCode, event);
            return true;
        }else if(mCurrentFragment instanceof NewToolsFragment){
            ((NewToolsFragment) mCurrentFragment).current().onKeyDown(keyCode, event);
            return true;
        }
        else if (keyCode==KeyEvent.KEYCODE_BACK && event.getRepeatCount() == 0) {
            long backPressed = System.currentTimeMillis();
            if (backPressed - lastBackPressed > QUIT_INTERVAL) {
                lastBackPressed = backPressed;
                Toast.makeText(this,"再按一次退出", Toast.LENGTH_LONG).show();
            } else {
                finish();
            }
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Nullable
    private Fragment getCurrentFragment() {
        if (viewPager == null) {
            return null;
        }
        return getSupportFragmentManager().findFragmentByTag("f" + viewPager.getCurrentItem());
    }

    private void checkPermission() {
        mPermissionList.clear();
        //判断哪些权限未授予
        for (int i = 0; i < permissions.length; i++) {
            if (ContextCompat.checkSelfPermission(this, permissions[i]) != PackageManager.PERMISSION_GRANTED) {
                mPermissionList.add(permissions[i]);
            }
        }
        /**
         * 判断是否为空
         */
        if (mPermissionList.isEmpty()) {//未授予的权限为空，表示都授予了
        } else {//请求权限方法
            String[] permissions = mPermissionList.toArray(new String[mPermissionList.size()]);//将List转为数组
            ActivityCompat.requestPermissions(TestActivity.this, permissions, PERMISSION_REQUEST);
        }
    }
    /**
     * 响应授权
     * 这里不管用户是否拒绝，都进入首页，不再重复申请权限
     */
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        switch (requestCode) {
            case PERMISSION_REQUEST:
                break;
            default:
                super.onRequestPermissionsResult(requestCode, permissions, grantResults);
                break;
        }
        initX5();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        switch (requestCode){
            case REQUEST_DIALOG_PERMISSION:
                floatHelper.show();
                ACache aCache = ACache.get(this);
                aCache.put("isShowFloatingBall", "yes");
                aCache.put("isNoLongerShowFloatingBall", "no");
                break;
            default:
                super.onActivityResult(requestCode, resultCode, data);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        floatHelper.release();
        wl.release();
        wifiLock.release();
        Log.i("TestActivity", "onDestroy: ");
    }
    //实现暂停音乐



}
