package com.example.asasfans.ui.main.adapter;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.viewpager2.adapter.FragmentStateAdapter;

import com.example.asasfans.data.DBOpenHelper;
import com.example.asasfans.ui.main.fragment.BlacklistTabsFragment;
import com.example.asasfans.ui.main.fragment.NullFragment;
import com.example.asasfans.util.ApiConfig;

import java.util.ArrayList;
import java.util.List;

public class BlacklistPagerAdapter extends FragmentStateAdapter {
    private static final String[] TAB_TITLES = new String[]{"TAG黑名单", "作者黑名单", "视频黑名单"};
    private final Context context;

    public BlacklistPagerAdapter(Fragment fragment) {
        super(fragment);
        this.context = fragment.getContext();
    }

    @NonNull
    @Override
    public Fragment createFragment(int position) {
        List<String> name;
        DBOpenHelper dbOpenHelper = new DBOpenHelper(context,"blackList.db",null,DBOpenHelper.DB_VERSION);
        SQLiteDatabase sqliteDatabase = dbOpenHelper.getReadableDatabase();
        Cursor cursor;
        switch (position){
            case 2:
                name = new ArrayList<>();
                cursor = sqliteDatabase.query("blackBvid",null,null,null,null,null,null);
                if (cursor.getCount() > 0) {
                    int titleColumn = cursor.getColumnIndexOrThrow("Title");
                    while (cursor.moveToNext()) {
                        name.add(cursor.getString(titleColumn));
                    }
                }
                sqliteDatabase.close();
                dbOpenHelper.close();
                return BlacklistTabsFragment.newInstance(ApiConfig.listToString(name, ","), "blackBvid", "Title");
            case 1:
                name = new ArrayList<>();
                cursor = sqliteDatabase.query("blackMid",null,null,null,null,null,null);
                if (cursor.getCount() > 0) {
                    int midColumn = cursor.getColumnIndexOrThrow("mid");
                    while (cursor.moveToNext()) {
                        name.add(cursor.getString(midColumn));
                    }
                }
                sqliteDatabase.close();
                dbOpenHelper.close();
                return BlacklistTabsFragment.newInstance(ApiConfig.listToString(name, ","), "blackMid", "mid");
            case 0:
                name = new ArrayList<>();
                cursor = sqliteDatabase.query("blackTag",null,null,null,null,null,null);
                if (cursor.getCount() > 0) {
                    int tagColumn = cursor.getColumnIndexOrThrow("tag");
                    while (cursor.moveToNext()) {
                        name.add(cursor.getString(tagColumn));
                    }
                }
                sqliteDatabase.close();
                dbOpenHelper.close();
                return BlacklistTabsFragment.newInstance(ApiConfig.listToString(name, ","), "blackTag", "tag");
            default:
                return NullFragment.newInstance();
        }
    }

    @Override
    public int getItemCount() {
        return TAB_TITLES.length;
    }

    public CharSequence getPageTitle(int position) {
        return TAB_TITLES[position];
    }
}
