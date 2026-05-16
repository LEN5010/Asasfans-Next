package com.example.asasfans.ui.main.fragment;

import static android.app.Activity.RESULT_CANCELED;
import static android.app.Activity.RESULT_OK;
import static android.content.Context.DOWNLOAD_SERVICE;

import android.annotation.SuppressLint;
import android.app.DownloadManager;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.text.TextUtils;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.tencent.smtt.export.external.interfaces.WebResourceRequest;
import com.tencent.smtt.sdk.DownloadListener;
import android.webkit.URLUtil;
import com.tencent.smtt.sdk.CookieManager;
import com.tencent.smtt.sdk.ValueCallback;
import com.tencent.smtt.sdk.WebChromeClient;
import android.webkit.WebResourceError;

import com.tencent.smtt.export.external.interfaces.WebResourceResponse;
import com.tencent.smtt.sdk.WebSettings;
import com.tencent.smtt.sdk.WebView;
import com.tencent.smtt.sdk.WebViewClient;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.asasfans.R;
import com.example.asasfans.ui.main.VideoProxyManager;
import com.example.asasfans.util.SystemUtils;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;


/**
 * @author akarinini
 * @description webFragment，使用WebView直接加载URL显示，属于BottomPagerAdapter
 */

public class WebFragment extends Fragment {
    public WebView webView;
    private ProgressBar progressBar;
    private long exitTime = 0;
    private String url = "https://cnki.asoul.us.kg/";
    private static final String CALENDAR_HOST = "asoul.love";
    private static final String CALENDAR_CHROME_USER_AGENT = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
    private static final int REQUEST_CODE_FILE_CHOOSER = 1;

    private ValueCallback<Uri> mUploadCallbackForLowApi;
    private ValueCallback<Uri[]> mUploadCallbackForHighApi;

    private Boolean inBottom = true;
    private boolean calendarFallbackOpened = false;

    private WebResourceResponse webResourceResponse = null;
    private String proxyUrl;
    private InputStream is;
    public static WebFragment newInstance(String url, Boolean inBottom) {
        WebFragment fragment = new WebFragment();
        Bundle args = new Bundle();
        args.putString("WebUrl", url);
        args.putBoolean("Bottom", inBottom);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.url = getArguments().getString("WebUrl");
        this.inBottom = getArguments().getBoolean("Bottom");
        // This callback will only be called when MyFragment is at least Started.
//        OnBackPressedCallback callback = new OnBackPressedCallback(true /* enabled by default */) {
//            @Override
//            public void handleOnBackPressed() {
//                // Handle the back button event
//                if (webView.canGoBack()) {
//                    webView.goBack();
//                }else {
//                    getActivity().onBackPressed();
//                }
//            }
//        };
//        requireActivity().getOnBackPressedDispatcher().addCallback(this, callback);

        // The callback can be enabled or disabled here or in handleOnBackPressed()
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode == REQUEST_CODE_FILE_CHOOSER && (resultCode == RESULT_OK || resultCode == RESULT_CANCELED)) {
            afterFileChooseGoing(resultCode, data);
        }
    }

    private void afterFileChooseGoing(int resultCode, Intent data) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (mUploadCallbackForHighApi == null) {
                return;
            }
            mUploadCallbackForHighApi.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data));
            mUploadCallbackForHighApi = null;
        } else {
            if (mUploadCallbackForLowApi == null) {
                return;
            }
            Uri result = data == null ? null : data.getData();
            mUploadCallbackForLowApi.onReceiveValue(result);
            mUploadCallbackForLowApi = null;
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view;
        //兼容状态栏
        if (inBottom) {
            view = inflater.inflate(R.layout.fragment_web, container, false);
        }else {
            view = inflater.inflate(R.layout.fragment_tools_web, container, false);
        }

        webView = view.findViewById(R.id.webView);
        progressBar = view.findViewById(R.id.pb);
        webView.setBackgroundColor(requireContext().getColor(R.color.cardWhite));
//        RefreshLayout refreshLayout = (RefreshLayout)view.findViewById(R.id.web_refreshLayout);
//        //先关掉下拉刷新
//        refreshLayout.setEnableRefresh(false);
//        refreshLayout.setRefreshHeader(new BezierRadarHeader(getActivity()));
//        refreshLayout.setOnRefreshListener(new OnRefreshListener() {
//            @Override
//            public void onRefresh(@NonNull RefreshLayout refreshLayout) {
//                webView.loadUrl(url);
//                refreshLayout.finishRefresh();
//            }
//        });

        webView.getSettings().setDatabaseEnabled(true);

        WebSettings webSettings = webView.getSettings();
        webSettings.setJavaScriptCanOpenWindowsAutomatically(true);//设置js可以直接打开窗口，如window.open()，默认为false
        webSettings.setJavaScriptEnabled(true);//是否允许JavaScript脚本运行，默认为false。设置true时，会提醒可能造成XSS漏洞
        webSettings.setSupportZoom(true);//是否可以缩放，默认true
        webSettings.setUseWideViewPort(true);//设置此属性，可任意比例缩放。大视图模式
        webSettings.setLoadWithOverviewMode(true);//和setUseWideViewPort(true)一起解决网页自适应问题
        webSettings.setAppCacheEnabled(true);//是否使用缓存
        webSettings.setDomStorageEnabled(true);//开启本地DOM存储
        webSettings.setLoadsImagesAutomatically(true); // 加载图片
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT);
        webSettings.setBuiltInZoomControls(true);
        webSettings.setDisplayZoomControls(false);
        configureCalendarCompatibility(webSettings);
//        webView.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
//        webSettings.setMixedContentMode(WebSettings.);


        //第一次加载时间会很长，添加加载动画
        webView.setWebChromeClient(new WebChromeClient(){
            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
                mUploadCallbackForHighApi = filePathCallback;
                Intent intent = fileChooserParams.createIntent();
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                try {
                    startActivityForResult(intent, REQUEST_CODE_FILE_CHOOSER);
//                    Toast.makeText(getActivity(), "can_open_file_chooser", Toast.LENGTH_LONG).show();
                } catch (ActivityNotFoundException e) {
                    mUploadCallbackForHighApi = null;
//                    Toast.makeText(getActivity(), "R.string.cant_open_file_chooser", Toast.LENGTH_LONG).show();
                    return false;
                }
                return true;
            }

            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                super.onProgressChanged(view, newProgress);
                if (newProgress <= 100) {
                    progressBar.setProgress(newProgress);
                }

            }
        });

        webView.setWebViewClient(new WebViewClient(){
            @Override
            public boolean shouldOverrideKeyEvent(WebView view, KeyEvent event) {
                return super.shouldOverrideKeyEvent(view, event);
            }

            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, com.tencent.smtt.export.external.interfaces.WebResourceRequest request) {
                Log.i("shouldInterceptRequest:getUrl", request.getUrl().toString());
                /*
                if (request.getUrl().toString().startsWith("https://asbbs-static-01.kzmidc.workers.dev/?file=/uploads/files/1/banner_1646556711136.mp4") ||
                        request.getUrl().toString().startsWith("https://as-archive-cn-01.a-soul.fans/") ||
                        request.getUrl().toString().startsWith("https://as-archive-load-balance.kzmidc.workers.dev") ||
                        request.getUrl().toString().startsWith("https://cn.as-archive.studio.asf.ink/AZCN-Sharepoint")
                        || request.getUrl().toString().startsWith("https://as-archive-azcn-0001.asf.ink/AZCN-Sharepoint")){
                    webResourceResponse = null;
                    proxyUrl = VideoProxyManager.getInstance().getProxyUrl(request.getUrl().toString());
//                    String proxyUrl = ProxyCacheUtils.getProxyUrl(uri.toString(), null, null);
                    Log.i("proxyUrl", proxyUrl);
//                    SystemUtils.inputStreamByUrl(proxyUrl);
                    is = null;
                    if (proxyUrl.startsWith("file://")){
                        try {
                            is = SystemUtils.inputStreamByUrl(proxyUrl.replaceFirst("file://",""));
                        } catch (FileNotFoundException e) {
                            e.printStackTrace();
                            webResourceResponse = null;
                        }
                        webResourceResponse = new WebResourceResponse("video/avc", "utf-8", is);
                    }else {

                        String[] tmp = proxyUrl.split("/");
//                            is = SystemUtils.inputStreamByUrl(proxyUrl);

                        //模拟音乐播放器放歌以触发videocache的缓存
                        //1.1创建okHttpClient
                        OkHttpClient okHttpClient = new OkHttpClient();

                        //1.2创建Request对象
                        Request okRequest = new Request.Builder().url(proxyUrl).build();

                        //2.把Request对象封装成call对象
                        Call call = okHttpClient.newCall(okRequest);

                        //3.发起异步请求
                        call.enqueue(new Callback() {
                            @Override
                            public void onFailure(Call call, IOException e) {
                                e.printStackTrace();
                            }
                            @Override
                            public void onResponse(Call call, Response response) throws IOException {
                                InputStream inputStream = response.body().byteStream();
                                webResourceResponse = new WebResourceResponse("video/avc", "utf-8", inputStream);
                            }
                        });
                    }
//                    is = null;
                    return webResourceResponse;
                }
                 */
//                else if (request.getUrl().toString().startsWith("https://jsxm.sharepoint.cn/sites/as-archive-cn-01")){
//                    return new WebResourceResponse("video/mp4", "utf-8", is);
//                }
                return super.shouldInterceptRequest(view, request);
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, com.tencent.smtt.export.external.interfaces.WebResourceRequest request) {
//                Log.i("WebResourceRequest:getUrl", request.getUrl().toString());
//                Log.i("WebResourceRequest:getMethod", request.getMethod());
                if (request.getUrl().toString().startsWith("http")) {
                    return super.shouldOverrideUrlLoading(view, request);
                }else {
                    try {
                        Intent it = new Intent();
                        it.setAction(Intent.ACTION_VIEW);
                        it.setData(Uri.parse(request.getUrl().toString()));
                        getActivity().startActivity(it);
                    }catch (Exception e){
                        Toast.makeText(getActivity(), "没有找到对应app", Toast.LENGTH_SHORT).show();
                    }
                    return true;
                }
            }

            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                progressBar.setVisibility(View.VISIBLE);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                progressBar.setVisibility(View.GONE);
            }

            @Override
            public void onReceivedError(WebView view, com.tencent.smtt.export.external.interfaces.WebResourceRequest request, com.tencent.smtt.export.external.interfaces.WebResourceError error) {
                super.onReceivedError(view, request, error);
                String failedUrl = request == null ? url : request.getUrl().toString();
                if (isMainFrameRequest(request) && isCalendarUrl(failedUrl)) {
                    openCalendarInBrowserAfterError(failedUrl);
                    return;
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    return;
                }
            }
        });

        webView.setDownloadListener(new DownloadListener() {
            @Override
            public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimetype, long contentLength) {
//                downloadByBrowser(url);
                try {
                    downloadByBrowser(url);
                }catch (Exception e){
                    e.printStackTrace();
                    Toast.makeText(getActivity(), "下载链接浏览器无法识别", Toast.LENGTH_SHORT).show();
                }
//                if (url.startsWith("http")) {
//
////                    downloadBySystem(url, contentDisposition, mimetype);
////                    // 使用
////                    DownloadCompleteReceiver receiver = new DownloadCompleteReceiver();
////                    IntentFilter intentFilter = new IntentFilter();
////                    intentFilter.addAction(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
////                    getActivity().registerReceiver(receiver, intentFilter);
//                }else {
//
//                }

            }
        });

        webView.loadUrl(url);
//        webView.loadUrl("https://asoul.cloud/pic");
//        webView.loadUrl("https://liulanmi.com/labs/core.html");
        return view;
    }

    public void reloadCurrentPage() {
        calendarFallbackOpened = false;
        if (webView != null) {
            String targetUrl = getCurrentOrInitialUrl();
            if (TextUtils.isEmpty(webView.getUrl()) && !TextUtils.isEmpty(targetUrl)) {
                webView.loadUrl(targetUrl);
            } else {
                webView.reload();
            }
        }
    }

    public void openCurrentUrlInBrowser() {
        String targetUrl = getCurrentOrInitialUrl();
        if (TextUtils.isEmpty(targetUrl)) {
            showToast(R.string.web_open_failed);
            return;
        }
        try {
            downloadByBrowser(targetUrl);
        } catch (Exception e) {
            showToast(R.string.web_open_failed);
        }
    }

    public void copyCurrentUrl() {
        String targetUrl = getCurrentOrInitialUrl();
        Context context = getContext();
        if (TextUtils.isEmpty(targetUrl) || context == null) {
            showToast(R.string.web_copy_failed);
            return;
        }
        ClipboardManager clipboardManager = (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboardManager == null) {
            showToast(R.string.web_copy_failed);
            return;
        }
        clipboardManager.setPrimaryClip(ClipData.newPlainText(getString(R.string.web_link_label), targetUrl));
        showToast(R.string.web_link_copied);
    }

    public String getCurrentOrInitialUrl() {
        if (webView != null && !TextUtils.isEmpty(webView.getUrl())) {
            return webView.getUrl();
        }
        return url;
    }

    private void showToast(int stringResId) {
        Context context = getContext();
        if (context != null) {
            Toast.makeText(context, stringResId, Toast.LENGTH_SHORT).show();
        }
    }

    private void configureCalendarCompatibility(WebSettings webSettings) {
        if (!isCalendarUrl(url)) {
            return;
        }
        webSettings.setUserAgentString(CALENDAR_CHROME_USER_AGENT);
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            cookieManager.setAcceptThirdPartyCookies(webView, true);
        }
    }

    public void onKeyDown(int keyCode, KeyEvent event) {
        if ((keyCode == KeyEvent.KEYCODE_BACK) && webView.canGoBack()) {
            Log.i("web:onKeyDown", "canGoBack: ");
            webView.goBack();
        }
        else if ((keyCode == KeyEvent.KEYCODE_BACK) && (!webView.canGoBack()) && event.getRepeatCount() == 0) {
            Log.i("web:onKeyDown", "can not GoBack: ");
            if ((System.currentTimeMillis() - exitTime) > 2000) {
                Toast.makeText(getActivity(), "再按一次退出程序", Toast.LENGTH_SHORT).show();
                exitTime = System.currentTimeMillis();
            } else {
                getActivity().finish();
            }
        }
    }
    public void onKeyDownInClick(int keyCode, KeyEvent event) {
        if ((keyCode == KeyEvent.KEYCODE_BACK) && webView.canGoBack()) {
            webView.goBack();
        }
        else if ((keyCode == KeyEvent.KEYCODE_BACK) && (!webView.canGoBack())) {
            getActivity().finish();
        }
    }


    private void downloadByBrowser(String url) {
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
        intent.addCategory(Intent.CATEGORY_BROWSABLE);
        getActivity().startActivity(intent);
    }

    private boolean isCalendarUrl(String targetUrl) {
        if (TextUtils.isEmpty(targetUrl)) {
            return false;
        }
        String host = Uri.parse(targetUrl).getHost();
        return host != null && (CALENDAR_HOST.equalsIgnoreCase(host) || host.endsWith("." + CALENDAR_HOST));
    }

    private boolean isMainFrameRequest(WebResourceRequest request) {
        return request == null || request.isForMainFrame();
    }

    private void openCalendarInBrowserAfterError(String failedUrl) {
        if (calendarFallbackOpened) {
            return;
        }
        calendarFallbackOpened = true;
        progressBar.setVisibility(View.GONE);
        try {
            if (getActivity() == null) {
                return;
            }
            downloadByBrowser(failedUrl);
            Toast.makeText(getActivity(), "日历站点在当前 WebView 中加载失败，已尝试用浏览器打开", Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(getActivity(), "日历站点加载失败，请稍后重试或用浏览器打开", Toast.LENGTH_LONG).show();
        }
    }

    private void downloadBySystem(String url, String contentDisposition, String mimeType) {
        // 指定下载地址
        DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
        // 允许媒体扫描，根据下载的文件类型被加入相册、音乐等媒体库
        request.allowScanningByMediaScanner();
        // 设置通知的显示类型，下载进行时和完成后显示通知
        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
        // 设置通知栏的标题，如果不设置，默认使用文件名
//        request.setTitle("This is title");
        // 设置通知栏的描述
//        request.setDescription("This is description");
        // 允许在计费流量下下载
        request.setAllowedOverMetered(false);
        // 允许该记录在下载管理界面可见
        request.setVisibleInDownloadsUi(false);
        // 允许漫游时下载
        request.setAllowedOverRoaming(true);
        // 允许下载的网路类型
        request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI);
        // 设置下载文件保存的路径和文件名
        String fileName  = URLUtil.guessFileName(url, contentDisposition, mimeType);
//        log.debug("fileName:{}", fileName);
        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
//        另外可选一下方法，自定义下载路径
//        request.setDestinationUri()
//        request.setDestinationInExternalFilesDir()
        final DownloadManager downloadManager = (DownloadManager) getActivity().getSystemService(DOWNLOAD_SERVICE);
        // 添加一个下载任务
        long downloadId = downloadManager.enqueue(request);
//        log.debug("downloadId:{}", downloadId);
    }

    private class DownloadCompleteReceiver extends BroadcastReceiver {

        @Override
        public void onReceive(Context context, Intent intent) {
//            log.verbose("onReceive. intent:{}", intent != null ? intent.toUri(0) : null);
            if (intent != null) {
                if (DownloadManager.ACTION_DOWNLOAD_COMPLETE.equals(intent.getAction())) {
                    long downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
//                    log.debug("downloadId:{}", downloadId);
                    DownloadManager downloadManager = (DownloadManager) context.getSystemService(DOWNLOAD_SERVICE);
                    String type = downloadManager.getMimeTypeForDownloadedFile(downloadId);
//                    log.debug("getMimeTypeForDownloadedFile:{}", type);
                    if (TextUtils.isEmpty(type)) {
                        type = "*/*";
                    }
                    Uri uri = downloadManager.getUriForDownloadedFile(downloadId);
//                    log.debug("UriForDownloadedFile:{}", uri);
                    if (uri != null) {
                        Intent handlerIntent = new Intent(Intent.ACTION_VIEW);
                        handlerIntent.setDataAndType(uri, type);
                        context.startActivity(handlerIntent);
                    }
                }
            }
        }
    }
}
