package com.example.asasfans.ui.main.fragment;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.example.asasfans.R;
import com.example.asasfans.data.DBOpenHelper;
import com.example.asasfans.ui.customcomponent.RecyclerViewDecoration;
import com.example.asasfans.util.ApiConfig;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.orhanobut.dialogplus.DialogPlus;
import com.orhanobut.dialogplus.ViewHolder;

import java.util.ArrayList;
import java.util.List;

public class BlacklistTabsFragment extends Fragment {
    private String table;
    private String displayColumn;
    private String deleteColumn;
    private final List<Row> rows = new ArrayList<>();
    private BlacklistTabsAdapter blacklistTabsAdapter;
    private DialogPlus dialog;
    private View dialogView;

    public static BlacklistTabsFragment newInstance(String table, String displayColumn, String deleteColumn) {
        Bundle args = new Bundle();
        args.putString("table", table);
        args.putString("displayColumn", displayColumn);
        args.putString("deleteColumn", deleteColumn);
        BlacklistTabsFragment fragment = new BlacklistTabsFragment();
        fragment.setArguments(args);
        return fragment;
    }

    void initDialog(){
        dialog = DialogPlus.newDialog(getActivity())
                .setContentHolder(new ViewHolder(R.layout.dialog_blacklist_copy_export))
                .setContentHeight(ViewGroup.LayoutParams.WRAP_CONTENT)
                .setContentWidth(ViewGroup.LayoutParams.MATCH_PARENT)
                .setCancelable(true)
                .setContentBackgroundResource(R.color.transparent)
                .setGravity(Gravity.CENTER)
                .create();
        dialogView = dialog.getHolderView();
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_main, container, false);
        initDialog();
        RecyclerView recyclerView = view.findViewById(R.id.recyclerview);
        SwipeRefreshLayout refreshLayout = view.findViewById(R.id.refreshLayout);
        FloatingActionButton fabAdd = view.findViewById(R.id.fab_add);

        fabAdd.setVisibility(View.VISIBLE);
        refreshLayout.setEnabled(false);
        loadRowsFromDb();
        blacklistTabsAdapter = new BlacklistTabsAdapter(requireActivity(), rows);
        recyclerView.setAdapter(blacklistTabsAdapter);
        LinearLayoutManager linearLayoutManager = new LinearLayoutManager(getActivity(),LinearLayoutManager.VERTICAL,false);
        linearLayoutManager.setInitialPrefetchItemCount(2);
        recyclerView.setLayoutManager(linearLayoutManager);
        recyclerView.addItemDecoration(new RecyclerViewDecoration(8, 8));

        fabAdd.setOnClickListener(view1 -> showEditDialog());
        return view;
    }

    private void showEditDialog() {
        TextView exportToClip = dialogView.findViewById(R.id.export_to_clip);
        TextView copyFromClip = dialogView.findViewById(R.id.copy_from_clip);
        TextView importFromEdittext = dialogView.findViewById(R.id.import_from_edittext);
        EditText edittext = dialogView.findViewById(R.id.edittext);
        edittext.setText("");
        edittext.setHint(getInputHint());

        edittext.setOnFocusChangeListener((view, hasFocus) -> {
            if(!hasFocus && getActivity() != null){
                InputMethodManager manager = ((InputMethodManager)getActivity().getSystemService(Context.INPUT_METHOD_SERVICE));
                if (manager != null) {
                    manager.hideSoftInputFromWindow(view.getWindowToken(),InputMethodManager.HIDE_NOT_ALWAYS);
                }
            }
        });
        exportToClip.setOnClickListener(view -> exportToClipboard());
        copyFromClip.setOnClickListener(view -> {
            ClipboardManager clipboardManager = (ClipboardManager) requireActivity().getSystemService(Context.CLIPBOARD_SERVICE);
            ClipData clipData = clipboardManager == null ? null : clipboardManager.getPrimaryClip();
            if (clipData == null || clipData.getItemCount() == 0 || clipData.getItemAt(0) == null) {
                Toast.makeText(getActivity(),"剪贴板内容为空",Toast.LENGTH_SHORT).show();
                return;
            }
            insertStringToSqlite(String.valueOf(clipData.getItemAt(0).getText()));
        });
        importFromEdittext.setOnClickListener(view -> insertStringToSqlite(edittext.getText().toString()));
        dialog.show();
    }

    private String getInputHint() {
        if ("subscribedUp".equals(table)) {
            return "每行一个：uid 或 uid,昵称 或 uid,昵称,备注";
        }
        if ("blackMid".equals(table)) {
            return "每行一个 UID，也支持逗号或加号分隔";
        }
        if ("blackBvid".equals(table)) {
            return "每行一个 BV 号，也支持逗号或加号分隔";
        }
        return "每行一个黑名单词，也支持逗号或加号分隔";
    }

    private void exportToClipboard() {
        List<String> values = new ArrayList<>();
        for (Row row : rows) {
            values.add(row.deleteValue);
        }
        String content = ApiConfig.listToString(values, "\n");
        ClipboardManager cm = (ClipboardManager) requireActivity().getSystemService(Context.CLIPBOARD_SERVICE);
        cm.setPrimaryClip(ClipData.newPlainText(table, content));
        Toast.makeText(getActivity(),"导出成功",Toast.LENGTH_SHORT).show();
    }

    private void insertStringToSqlite(String input){
        if (input == null || input.trim().isEmpty()) {
            Toast.makeText(getActivity(),"请输入内容",Toast.LENGTH_SHORT).show();
            return;
        }
        if (input.startsWith("tag.") && input.endsWith(".uid")) {
            importLegacyBlacklist(input);
            refreshRows();
            dialog.dismiss();
            return;
        }
        DBOpenHelper dbOpenHelper = new DBOpenHelper(getActivity(),"blackList.db",null,DBOpenHelper.DB_VERSION);
        SQLiteDatabase sqliteDatabase = dbOpenHelper.getWritableDatabase();
        try {
            String[] lines = "subscribedUp".equals(table) ? input.split("\\n") : input.split("[\\n,+，]+");
            for (String raw : lines) {
                String value = raw.trim();
                if (value.isEmpty()) {
                    continue;
                }
                if ("subscribedUp".equals(table)) {
                    insertSubscribedUp(sqliteDatabase, raw);
                } else if ("blackMid".equals(table)) {
                    insertMid(sqliteDatabase, value);
                } else if ("blackBvid".equals(table)) {
                    ContentValues values = new ContentValues();
                    values.put("bvid", value);
                    values.put("Title", value);
                    sqliteDatabase.insertWithOnConflict("blackBvid", null, values, SQLiteDatabase.CONFLICT_IGNORE);
                } else {
                    ContentValues values = new ContentValues();
                    values.put("word", value);
                    sqliteDatabase.insertWithOnConflict("blackWord", null, values, SQLiteDatabase.CONFLICT_IGNORE);
                }
            }
            Toast.makeText(getActivity(),"添加成功",Toast.LENGTH_SHORT).show();
        } finally {
            sqliteDatabase.close();
            dbOpenHelper.close();
        }
        refreshRows();
        dialog.dismiss();
    }

    private void insertSubscribedUp(SQLiteDatabase sqliteDatabase, String raw) {
        String[] fields = raw.split("[,，]", 3);
        String mid = fields[0].trim();
        if (!isNumeric(mid)) {
            Toast.makeText(getActivity(),"UID 需要是纯数字：" + mid,Toast.LENGTH_SHORT).show();
            return;
        }
        ContentValues values = new ContentValues();
        values.put("mid", Long.valueOf(mid));
        values.put("name", fields.length > 1 ? fields[1].trim() : "");
        values.put("face", "");
        values.put("note", fields.length > 2 ? fields[2].trim() : "");
        values.put("updatedAt", System.currentTimeMillis() / 1000);
        sqliteDatabase.insertWithOnConflict("subscribedUp", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    private void insertMid(SQLiteDatabase sqliteDatabase, String value) {
        if (!isNumeric(value)) {
            Toast.makeText(getActivity(),"UID 需要是纯数字：" + value,Toast.LENGTH_SHORT).show();
            return;
        }
        ContentValues values = new ContentValues();
        values.put("mid", Long.valueOf(value));
        sqliteDatabase.insertWithOnConflict("blackMid", null, values, SQLiteDatabase.CONFLICT_IGNORE);
    }

    private void importLegacyBlacklist(String s){
        String[] s2 = s.split("~");
        if (s2.length != 2) {
            Toast.makeText(getActivity(),"导入的语句不符合格式要求",Toast.LENGTH_SHORT).show();
            return;
        }
        String[] tagTmp = s2[0].split("\\.");
        String[] midTmp = s2[1].split("\\.");
        if (tagTmp.length != 3 || midTmp.length != 3) {
            Toast.makeText(getActivity(),"导入的语句不符合格式要求",Toast.LENGTH_SHORT).show();
            return;
        }
        DBOpenHelper dbOpenHelper = new DBOpenHelper(getActivity(),"blackList.db",null,DBOpenHelper.DB_VERSION);
        SQLiteDatabase sqliteDatabase = dbOpenHelper.getWritableDatabase();
        try {
            for (String tag : tagTmp[1].split("\\+")) {
                if (!tag.isEmpty()) {
                    ContentValues values = new ContentValues();
                    values.put("word", tag);
                    sqliteDatabase.insertWithOnConflict("blackWord", null, values, SQLiteDatabase.CONFLICT_IGNORE);
                }
            }
            for (String mid : midTmp[1].split("\\+")) {
                if (!mid.isEmpty()) {
                    insertMid(sqliteDatabase, mid);
                }
            }
            Toast.makeText(getActivity(),"导入成功",Toast.LENGTH_SHORT).show();
        } finally {
            sqliteDatabase.close();
            dbOpenHelper.close();
        }
    }

    private void refreshRows() {
        loadRowsFromDb();
        blacklistTabsAdapter.notifyDataSetChanged();
    }

    private void loadRowsFromDb() {
        rows.clear();
        DBOpenHelper dbOpenHelper = new DBOpenHelper(getActivity(),"blackList.db",null,DBOpenHelper.DB_VERSION);
        SQLiteDatabase sqliteDatabase = dbOpenHelper.getReadableDatabase();
        Cursor cursor = null;
        try {
            cursor = sqliteDatabase.query(table,null,null,null,null,null,null);
            while (cursor.moveToNext()) {
                rows.add(rowFromCursor(cursor));
            }
        } finally {
            if (cursor != null) {
                cursor.close();
            }
            sqliteDatabase.close();
            dbOpenHelper.close();
        }
    }

    private Row rowFromCursor(Cursor cursor) {
        if ("subscribedUp".equals(table)) {
            String mid = cursor.getString(cursor.getColumnIndexOrThrow("mid"));
            String name = cursor.getString(cursor.getColumnIndexOrThrow("name"));
            String note = cursor.getString(cursor.getColumnIndexOrThrow("note"));
            String display = mid + (name == null || name.isEmpty() ? "" : "  " + name)
                    + (note == null || note.isEmpty() ? "" : "  " + note);
            return new Row(display, mid);
        }
        String deleteValue = cursor.getString(cursor.getColumnIndexOrThrow(deleteColumn));
        String display = cursor.getString(cursor.getColumnIndexOrThrow(displayColumn));
        if (display == null || display.isEmpty()) {
            display = deleteValue;
        }
        return new Row(display, deleteValue);
    }

    public final static boolean isNumeric(String str){
        return str != null && !"".equals(str.trim()) && str.matches("^[0-9]*$");
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        table = getArguments().getString("table");
        displayColumn = getArguments().getString("displayColumn");
        deleteColumn = getArguments().getString("deleteColumn");
        super.onCreate(savedInstanceState);
    }

    public class BlacklistTabsAdapter extends RecyclerView.Adapter<BlacklistViewHolder> {
        Context context;
        List<Row> rowList;

        public BlacklistTabsAdapter(Context context, List<Row> rowList) {
            this.context = context;
            this.rowList = rowList;
        }

        @NonNull
        @Override
        public BlacklistViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(context).inflate(R.layout.blacklist_recyclerview, parent,false);
            BlacklistViewHolder blacklistViewHolder = new BlacklistViewHolder(view);
            blacklistViewHolder.delete.setOnClickListener(view1 -> {
                int position = blacklistViewHolder.getBindingAdapterPosition();
                if (position == RecyclerView.NO_POSITION) {
                    return;
                }
                DBOpenHelper dbOpenHelper = new DBOpenHelper(context,"blackList.db",null,DBOpenHelper.DB_VERSION);
                SQLiteDatabase sqliteDatabase = dbOpenHelper.getWritableDatabase();
                sqliteDatabase.delete(table, deleteColumn + "=?", new String[]{rowList.get(position).deleteValue});
                sqliteDatabase.close();
                dbOpenHelper.close();
                rowList.remove(position);
                notifyItemRemoved(position);
                Toast.makeText(context,"删除成功",Toast.LENGTH_SHORT).show();
            });
            return blacklistViewHolder;
        }

        @Override
        public void onBindViewHolder(@NonNull BlacklistViewHolder holder, int position) {
            holder.name.setText(rowList.get(position).display);
        }

        @Override
        public int getItemCount() {
            return rowList.size();
        }
    }

    public static class Row {
        final String display;
        final String deleteValue;

        Row(String display, String deleteValue) {
            this.display = display;
            this.deleteValue = deleteValue;
        }
    }

    public class BlacklistViewHolder extends RecyclerView.ViewHolder{
        private TextView name;
        private TextView delete;

        public BlacklistViewHolder(@NonNull View itemView) {
            super(itemView);
            delete = itemView.findViewById(R.id.delete);
            name = itemView.findViewById(R.id.blacklist_text);
        }
    }
}
