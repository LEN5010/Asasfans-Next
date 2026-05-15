package com.example.asasfans.ui.bili;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.asasfans.R;
import com.example.asasfans.bili.BiliApiClient;
import com.example.asasfans.bili.BiliAuthRepository;
import com.example.asasfans.bili.BiliCredentialStore;
import com.example.asasfans.bili.BiliModels;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import coil.Coil;
import coil.request.ImageRequest;

public class BiliAccountFragment extends Fragment {
    private static final int QR_CODE_SIZE = 640;
    private static final long POLL_DELAY_MS = 2000L;
    private static final String PASSWORD_LOGIN_URL = "https://passport.bilibili.com/login";

    private ImageView avatar;
    private ImageView qrImage;
    private TextView accountName;
    private TextView accountStatus;
    private TextView loginStatus;
    private LinearLayout qrPanel;
    private LinearLayout passwordPanel;
    private ProgressBar webProgress;
    private WebView webView;
    private BiliCredentialStore credentialStore;
    private BiliAuthRepository authRepository;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private String currentQrKey = "";
    private boolean destroyed;

    private final Runnable pollRunnable = new Runnable() {
        @Override
        public void run() {
            pollQrCode();
        }
    };

    public static BiliAccountFragment newInstance() {
        Bundle args = new Bundle();
        BiliAccountFragment fragment = new BiliAccountFragment();
        fragment.setArguments(args);
        return fragment;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        destroyed = false;
        View view = inflater.inflate(R.layout.fragment_bili_account, container, false);
        bindViews(view);
        setupRepositories();
        setupActions(view);
        setupWebView();
        loadAccountStatus(true);
        return view;
    }

    private void bindViews(View view) {
        avatar = view.findViewById(R.id.account_avatar);
        qrImage = view.findViewById(R.id.account_qr_image);
        accountName = view.findViewById(R.id.account_name);
        accountStatus = view.findViewById(R.id.account_status);
        loginStatus = view.findViewById(R.id.account_login_status);
        qrPanel = view.findViewById(R.id.qr_login_panel);
        passwordPanel = view.findViewById(R.id.password_login_panel);
        webProgress = view.findViewById(R.id.account_web_progress);
        webView = view.findViewById(R.id.account_webview);
    }

    private void setupRepositories() {
        credentialStore = new BiliCredentialStore(requireContext());
        BiliApiClient apiClient = new BiliApiClient(credentialStore);
        authRepository = new BiliAuthRepository(apiClient, credentialStore);
    }

    private void setupActions(View view) {
        MaterialButtonToggleGroup modeGroup = view.findViewById(R.id.login_mode_group);
        modeGroup.check(R.id.login_mode_qr);
        modeGroup.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
            if (!isChecked) {
                return;
            }
            if (checkedId == R.id.login_mode_qr) {
                showQrPanel();
            } else if (checkedId == R.id.login_mode_password) {
                showPasswordPanel();
            }
        });
        MaterialButton refreshQr = view.findViewById(R.id.account_refresh_qr);
        refreshQr.setOnClickListener(v -> generateQrCode());
        MaterialButton logout = view.findViewById(R.id.account_logout);
        logout.setOnClickListener(v -> {
            authRepository.logout();
            CookieManager.getInstance().removeAllCookies(null);
            CookieManager.getInstance().flush();
            setLoggedOut();
            generateQrCode();
        });
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void setupWebView() {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        CookieManager.getInstance().setAcceptCookie(true);
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                webProgress.setProgress(newProgress);
                webProgress.setVisibility(newProgress >= 100 ? View.GONE : View.VISIBLE);
            }
        });
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                syncWebCookiesAndCheck();
            }
        });
    }

    private void showQrPanel() {
        passwordPanel.setVisibility(View.GONE);
        qrPanel.setVisibility(View.VISIBLE);
        mainHandler.removeCallbacks(pollRunnable);
        if (currentQrKey.isEmpty()) {
            generateQrCode();
        } else {
            schedulePoll();
        }
    }

    private void showPasswordPanel() {
        mainHandler.removeCallbacks(pollRunnable);
        qrPanel.setVisibility(View.GONE);
        passwordPanel.setVisibility(View.VISIBLE);
        if (webView.getUrl() == null) {
            webView.loadUrl(PASSWORD_LOGIN_URL);
        }
    }

    private void loadAccountStatus(boolean generateQrWhenLoggedOut) {
        executor.execute(() -> {
            try {
                BiliModels.NavResponse nav = authRepository.getNav();
                if (nav != null && nav.data != null && nav.data.isLogin) {
                    requireActivity().runOnUiThread(() -> showLoggedIn(nav.data));
                } else {
                    requireActivity().runOnUiThread(() -> {
                        setLoggedOut();
                        if (generateQrWhenLoggedOut) {
                            generateQrCode();
                        }
                    });
                }
            } catch (Exception e) {
                requireActivity().runOnUiThread(() -> {
                    setLoggedOut();
                    if (generateQrWhenLoggedOut) {
                        generateQrCode();
                    }
                });
            }
        });
    }

    private void showLoggedIn(BiliModels.NavData data) {
        mainHandler.removeCallbacks(pollRunnable);
        accountName.setText(data.uname == null ? getString(R.string.bili_account) : data.uname);
        accountStatus.setText(getString(R.string.bili_account_logged_in, data.uname == null ? "" : data.uname));
        loginStatus.setText(R.string.bili_login_success);
        if (data.face != null && !data.face.isEmpty()) {
            Coil.imageLoader(requireContext()).enqueue(new ImageRequest.Builder(requireContext())
                    .data(data.face)
                    .target(avatar)
                    .build());
        }
    }

    private void setLoggedOut() {
        accountName.setText(R.string.bili_account);
        accountStatus.setText(R.string.bili_account_not_logged_in);
        loginStatus.setText(R.string.bili_qr_loading);
        avatar.setImageResource(R.drawable.ic_bili_up);
    }

    private void generateQrCode() {
        mainHandler.removeCallbacks(pollRunnable);
        currentQrKey = "";
        loginStatus.setText(R.string.bili_qr_loading);
        executor.execute(() -> {
            try {
                BiliModels.QrGenerateResponse response = authRepository.generateQrCode();
                Bitmap bitmap = createQrBitmap(response.data.url);
                currentQrKey = response.data.qrcodeKey;
                requireActivity().runOnUiThread(() -> {
                    qrImage.setImageBitmap(bitmap);
                    loginStatus.setText(R.string.bili_qr_wait_scan);
                    schedulePoll();
                });
            } catch (Exception e) {
                requireActivity().runOnUiThread(() -> loginStatus.setText(getString(R.string.bili_login_failed) + ": " + e.getMessage()));
            }
        });
    }

    private void pollQrCode() {
        if (destroyed || currentQrKey.isEmpty()) {
            return;
        }
        executor.execute(() -> {
            try {
                BiliModels.QrPollResponse response = authRepository.pollQrCode(currentQrKey);
                if (response == null || response.data == null) {
                    requireActivity().runOnUiThread(() -> loginStatus.setText(R.string.bili_login_failed));
                    return;
                }
                handlePollCode(response.data.code, response.data.message);
            } catch (Exception e) {
                requireActivity().runOnUiThread(() -> loginStatus.setText(getString(R.string.bili_login_failed) + ": " + e.getMessage()));
            }
        });
    }

    private void handlePollCode(int code, String message) {
        requireActivity().runOnUiThread(() -> {
            if (destroyed) {
                return;
            }
            if (code == 0) {
                loginStatus.setText(R.string.bili_login_success);
                mainHandler.removeCallbacks(pollRunnable);
                loadAccountStatus(false);
            } else if (code == 86101) {
                loginStatus.setText(R.string.bili_qr_wait_scan);
                schedulePoll();
            } else if (code == 86090) {
                loginStatus.setText(R.string.bili_qr_wait_confirm);
                schedulePoll();
            } else if (code == 86038) {
                loginStatus.setText(R.string.bili_qr_expired);
                mainHandler.removeCallbacks(pollRunnable);
            } else {
                loginStatus.setText(message == null || message.isEmpty() ? getString(R.string.bili_login_failed) : message);
            }
        });
    }

    private void syncWebCookiesAndCheck() {
        String passportCookie = CookieManager.getInstance().getCookie("https://passport.bilibili.com");
        String biliCookie = CookieManager.getInstance().getCookie("https://www.bilibili.com");
        credentialStore.saveFromCookieString(passportCookie);
        credentialStore.saveFromCookieString(biliCookie);
        if (credentialStore.hasLoginCookie()) {
            loadAccountStatus(false);
        }
    }

    private void schedulePoll() {
        if (destroyed || qrPanel.getVisibility() != View.VISIBLE) {
            return;
        }
        mainHandler.removeCallbacks(pollRunnable);
        mainHandler.postDelayed(pollRunnable, POLL_DELAY_MS);
    }

    private Bitmap createQrBitmap(String content) throws Exception {
        BitMatrix bitMatrix = new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, QR_CODE_SIZE, QR_CODE_SIZE);
        Bitmap bitmap = Bitmap.createBitmap(QR_CODE_SIZE, QR_CODE_SIZE, Bitmap.Config.RGB_565);
        for (int x = 0; x < QR_CODE_SIZE; x++) {
            for (int y = 0; y < QR_CODE_SIZE; y++) {
                bitmap.setPixel(x, y, bitMatrix.get(x, y) ? 0xff111111 : 0xffffffff);
            }
        }
        return bitmap;
    }

    @Override
    public void onDestroyView() {
        destroyed = true;
        mainHandler.removeCallbacks(pollRunnable);
        super.onDestroyView();
    }

    @Override
    public void onDestroy() {
        executor.shutdownNow();
        super.onDestroy();
    }
}
