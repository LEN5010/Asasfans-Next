package com.example.asasfans.ui.main.adapter;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.viewpager2.adapter.FragmentStateAdapter;

import com.example.asasfans.ui.main.fragment.MainFragment;
import com.example.asasfans.ui.main.fragment.NewToolsFragment;
import com.example.asasfans.ui.main.fragment.NullFragment;
import com.example.asasfans.ui.main.fragment.WebFragment;

public class NewBottomPagerAdapter extends FragmentStateAdapter {
    private static final int TAB_COUNT = 4;
    private static Object currentFragment;

    public NewBottomPagerAdapter(@NonNull FragmentActivity fragmentActivity) {
        super(fragmentActivity);
    }

    @NonNull
    @Override
    public Fragment createFragment(int position) {
        switch (position) {
            case 0:
                return MainFragment.newInstance();
            case 1:
                return WebFragment.newInstance("https://studio.asoul.us.kg", true);
            case 2:
                return NewToolsFragment.newInstance();
            case 3:
                return WebFragment.newInstance("https://asoul.love", true);
            default:
                return NullFragment.newInstance();
        }
    }

    @Override
    public int getItemCount() {
        return TAB_COUNT;
    }

    public void setCurrentFragment(Object fragment) {
        currentFragment = fragment;
    }

    public static Object getCurrentFragment() {
        return currentFragment;
    }
}
