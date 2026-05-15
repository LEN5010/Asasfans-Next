package com.example.asasfans.ui.main.adapter;

import android.content.Context;

import androidx.annotation.StringRes;
import androidx.fragment.app.Fragment;
import androidx.viewpager2.adapter.FragmentStateAdapter;

import com.example.asasfans.R;
import com.example.asasfans.ui.main.fragment.BiliVideoFragment;
import com.example.asasfans.ui.main.fragment.NullFragment;
import com.example.asasfans.util.ACache;
import com.example.asasfans.util.ApiConfig;
import com.example.asasfans.util.QConstructor;

import java.util.Arrays;

public class SectionsPagerAdapter extends FragmentStateAdapter {

    @StringRes
    private static final int[] TAB_TITLES = new int[]{ R.string.tab_text_4, R.string.tab_text_5, R.string.tab_text_2};
    private final Context mContext;

    public SectionsPagerAdapter(Fragment fragment) {
        super(fragment);
        mContext = fragment.getContext();
    }

    @Override
    public Fragment createFragment(int position) {
        switch (position){
            case 0:
                return BiliVideoFragment.newInstance(new ApiConfig("score", 1,
                        new QConstructor.QArray("pubdate", Arrays.asList(String.valueOf(System.currentTimeMillis()/1000 - 3 * ACache.TIME_DAY), String.valueOf(System.currentTimeMillis()/1000)), "BETWEEN").toString(), "1", "").getUrl());
            case 1:
                return BiliVideoFragment.newInstance(new ApiConfig("score", 1,
                        new QConstructor.QArray("pubdate", Arrays.asList(String.valueOf(System.currentTimeMillis()/1000 - 3 * ACache.TIME_DAY), String.valueOf(System.currentTimeMillis()/1000)), "BETWEEN").toString(), "2", "").getUrl());
            case 2:
                return BiliVideoFragment.newInstance(new ApiConfig("pubdate", 1, "", "", "").getUrl());
            default:
                return NullFragment.newInstance();
        }
    }

    @Override
    public int getItemCount() {
        return TAB_TITLES.length;
    }

    public CharSequence getPageTitle(int position) {
        return mContext.getResources().getString(TAB_TITLES[position]);
    }
}
