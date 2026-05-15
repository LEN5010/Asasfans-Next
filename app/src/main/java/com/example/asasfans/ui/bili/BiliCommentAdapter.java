package com.example.asasfans.ui.bili;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.asasfans.R;
import com.example.asasfans.bili.BiliModels;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

import coil.Coil;
import coil.request.ImageRequest;

public class BiliCommentAdapter extends RecyclerView.Adapter<BiliCommentAdapter.CommentViewHolder> {
    private final Context context;
    private final List<BiliModels.Reply> replies = new ArrayList<>();
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.CHINA);

    public BiliCommentAdapter(Context context) {
        this.context = context;
    }

    public void setReplies(List<BiliModels.Reply> newReplies) {
        replies.clear();
        if (newReplies != null) {
            replies.addAll(newReplies);
        }
        notifyDataSetChanged();
    }

    public void addReplies(List<BiliModels.Reply> moreReplies) {
        if (moreReplies == null || moreReplies.isEmpty()) {
            return;
        }
        int start = replies.size();
        replies.addAll(moreReplies);
        notifyItemRangeInserted(start, moreReplies.size());
    }

    public int getReplyCount() {
        return replies.size();
    }

    @NonNull
    @Override
    public CommentViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(context).inflate(R.layout.item_bili_comment, parent, false);
        return new CommentViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull CommentViewHolder holder, int position) {
        BiliModels.Reply reply = replies.get(position);
        String user = reply.member == null || reply.member.uname == null ? "匿名用户" : reply.member.uname;
        String message = reply.content == null || reply.content.message == null ? "" : reply.content.message;
        holder.user.setText(user);
        holder.message.setText(message);
        holder.meta.setText(dateFormat.format(new Date(reply.ctime * 1000L)) + "  赞 " + reply.like + "  回复 " + reply.rcount);
        if (reply.member != null && reply.member.avatar != null && !reply.member.avatar.isEmpty()) {
            Coil.imageLoader(context).enqueue(new ImageRequest.Builder(context)
                    .data(reply.member.avatar)
                    .target(holder.avatar)
                    .build());
        } else {
            holder.avatar.setImageDrawable(null);
        }
    }

    @Override
    public int getItemCount() {
        return replies.size();
    }

    static class CommentViewHolder extends RecyclerView.ViewHolder {
        final ImageView avatar;
        final TextView user;
        final TextView message;
        final TextView meta;

        CommentViewHolder(@NonNull View itemView) {
            super(itemView);
            avatar = itemView.findViewById(R.id.comment_avatar);
            user = itemView.findViewById(R.id.comment_user);
            message = itemView.findViewById(R.id.comment_message);
            meta = itemView.findViewById(R.id.comment_meta);
        }
    }
}
