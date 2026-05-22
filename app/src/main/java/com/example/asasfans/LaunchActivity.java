package com.example.asasfans;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.example.asasfans.data.DBOpenHelper;
import com.example.asasfans.util.ACache;

import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * @author akarinini
 * @author LEN5010
 * @description 应用启动页，初始化本地数据库并检查最新版本后进入主界面。
 */

public class LaunchActivity extends AppCompatActivity {
    private static final int GET_DATA_SUCCESS = 1;
    private static final int NETWORK_ERROR = 2;
    private String latestVersion = "https://api.github.com/repos/LEN5010/Asasfans-Next/releases/latest";
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // 这两行其实tm屁用没有 其他地方的dbOpenHelper.getReadableDatabase()才能建库 闹麻了
        DBOpenHelper dbOpenHelper = new DBOpenHelper(this,"blackList.db",null, DBOpenHelper.DB_VERSION);
        dbOpenHelper.close();
        setContentView(R.layout.activity_lanch);
        // 启动页只做轻量初始化和版本检查，结果无论成功失败都进入主界面。
        new Thread(networkTask).start();
    }


    Handler handler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            super.handleMessage(msg);
            Bundle data = msg.getData();
            String val = data.getString("latestVersion");
            Log.i("latestVersion", "请求结果为-->" + val);
            //跳转至 MainActivity
            Intent intent = new Intent(LaunchActivity.this, TestActivity.class);
            intent.putExtras(data);
            startActivity(intent);
            // 结束启动页，避免返回键回到空白启动界面。
            LaunchActivity.this.finish();
        }
    };

    Runnable networkTask = new Runnable() {
        @Override
        public void run() {
            Message msg = new Message();
            Bundle data = new Bundle();
            msg.what = GET_DATA_SUCCESS;
            data.putString("latestVersion", "");
            ACache aCache = ACache.get(LaunchActivity.this);
            String tmpACache =  aCache.getAsString("latestVersion");
            if (tmpACache == null) {
                // GitHub latest release 响应缓存一天，降低冷启动时的网络失败影响。
                OkHttpClient client = new OkHttpClient.Builder().readTimeout(5, TimeUnit.SECONDS).build();
                Request request = new Request.Builder().url(latestVersion)
                        .get().build();
                Call call = client.newCall(request);
                try (Response response = call.execute()) {
                    if (response.body() != null) {
                        String tmp = response.body().string();
                        data.putString("latestVersion", tmp);
                        aCache.put("latestVersion", tmp, ACache.TIME_DAY);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    msg.what = NETWORK_ERROR;
                }
            }else {
                msg.what = GET_DATA_SUCCESS;
                data.putString("latestVersion", aCache.getAsString("latestVersion"));
                Log.i("ACache", aCache.getAsString("latestVersion"));
            }
            msg.setData(data);
            handler.sendMessage(msg);
        }
    };

}
