package com.example.asasfans.ui.main.fragment;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.viewpager2.widget.ViewPager2;

import com.example.asasfans.R;
import com.example.asasfans.ui.main.adapter.BlacklistPagerAdapter;
import com.google.android.material.tabs.TabLayout;
import com.google.android.material.tabs.TabLayoutMediator;

public class BlacklistFragment extends Fragment {
    public static BlacklistFragment newInstance() {
        Bundle args = new Bundle();
        BlacklistFragment fragment = new BlacklistFragment();
        fragment.setArguments(args);
        return fragment;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_blacklist, container, false);
        BlacklistPagerAdapter blacklistPagerAdapter = new BlacklistPagerAdapter(this);
        ViewPager2 viewPager = view.findViewById(R.id.view_pager);
        viewPager.setAdapter(blacklistPagerAdapter);
        viewPager.setOffscreenPageLimit(3);
        TabLayout tabs = view.findViewById(R.id.tabs);
        new TabLayoutMediator(tabs, viewPager, (tab, position) -> tab.setText(blacklistPagerAdapter.getPageTitle(position))).attach();
        return view;
    }
}
