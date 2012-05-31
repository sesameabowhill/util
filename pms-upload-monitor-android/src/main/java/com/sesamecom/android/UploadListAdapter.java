package com.sesamecom.android;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;
import com.sesamecom.android.model.MemberUploadInfo;
import com.sesamecom.android.model.UploadListView;

import java.util.Date;

/**
 * Created by Ivan
 */
public class UploadListAdapter extends BaseAdapter {
    public static final int TYPE_IN_PROGRESS = 0;
    public static final int TYPE_IN_QUEUE = 1;
    public static final int TYPE_IN_TITLE = 2;
    public static final int TYPE_COUNT = 3;

    private UploadListView uploadListView;
    private LayoutInflater inflater;

    public UploadListAdapter(UploadListView uploadListView, LayoutInflater inflater) {
        this.uploadListView = uploadListView;
        this.inflater = inflater;
    }

    @Override
    public int getItemViewType(int position) {
        if (position == 0) {
            return TYPE_IN_TITLE;
        } else if (position < uploadListView.getInProgressSize() + 1) {
            return TYPE_IN_PROGRESS;
        } else if (position == uploadListView.getInProgressSize() + 1) {
            return TYPE_IN_TITLE;
        } else {
            return TYPE_IN_QUEUE;
        }
    }

    @Override
    public int getViewTypeCount() {
        return TYPE_COUNT;
    }

    @Override
    public int getCount() {
        if (uploadListView.getInQueueSize() > 0) {
            return uploadListView.getInProgressSize() + uploadListView.getInQueueSize() + 2;
        } else {
            return uploadListView.getInProgressSize() + 1;
        }
    }

    @Override
    public MemberUploadInfo getItem(int index) {
        if (index == 0) {
            return null;
        } else if (index < uploadListView.getInProgressSize() + 1) {
            return uploadListView.getInProgress(index - 1);
        } else if (index == uploadListView.getInProgressSize() + 1) {
            return null;
        } else {
            return uploadListView.getInQueue(index - uploadListView.getInProgressSize() - 2);
        }
    }

    @Override
    public long getItemId(int index) {
        return index;
    }

    @Override
    public View getView(int index, View convertView, ViewGroup viewGroup) {
        ViewHolder viewHolder;
        final int viewType = getItemViewType(index);
        if (null == convertView) {
            viewHolder = new ViewHolder();
            switch (viewType) {
                case TYPE_IN_PROGRESS:
                    convertView = inflater.inflate(R.layout.upload_in_progress_item, null);
                    viewHolder.count = (TextView) convertView.findViewById(R.id.item_count);
                    viewHolder.message = (TextView) convertView.findViewById(R.id.item_message);
                    viewHolder.priority = (TextView) convertView.findViewById(R.id.item_priority);
                    viewHolder.stepDate = (TextView) convertView.findViewById(R.id.item_step_date);
                    viewHolder.uploadDate = (TextView) convertView.findViewById(R.id.item_upload_date);
                    viewHolder.username = (TextView) convertView.findViewById(R.id.item_username);
                    break;
                case TYPE_IN_QUEUE:
                    convertView = inflater.inflate(R.layout.upload_in_queue_item, null);
                    viewHolder.count = (TextView) convertView.findViewById(R.id.item_count);
                    viewHolder.priority = (TextView) convertView.findViewById(R.id.item_priority);
                    viewHolder.uploadDate = (TextView) convertView.findViewById(R.id.item_upload_date);
                    viewHolder.username = (TextView) convertView.findViewById(R.id.item_username);
                    break;
                case TYPE_IN_TITLE:
                    convertView = inflater.inflate(R.layout.upload_title, null);
                    viewHolder.message = (TextView) convertView.findViewById(R.id.text_upload_title);
                    break;
                default: throw new RuntimeException("unknown view type " + viewType);
            }
            convertView.setTag(viewHolder);
        } else {
            viewHolder = (ViewHolder) convertView.getTag();
        }
        Date now = new Date();
        MemberUploadInfo info = getItem(index);

        switch (viewType) {
            case TYPE_IN_PROGRESS:
                viewHolder.count.setText(Integer.toString(index));
                viewHolder.priority.setText(UploadListView.priorityToString(info.getPriority()));
                viewHolder.uploadDate.setText(UploadListView.diffBetweenDates(info.getStart(), now));
                viewHolder.username.setText(info.getUsername());
                viewHolder.message.setText(info.getMessage());
                viewHolder.stepDate.setText(UploadListView.diffBetweenDates(info.getUpdate(), now));
                break;
            case TYPE_IN_QUEUE:
                viewHolder.count.setText(Integer.toString(index - 1 - uploadListView.getInProgressSize()));
                viewHolder.priority.setText(UploadListView.priorityToString(info.getPriority()));
                viewHolder.uploadDate.setText(UploadListView.diffBetweenDates(info.getStart(), now));
                viewHolder.username.setText(info.getUsername());
                break;
            case TYPE_IN_TITLE:
                viewHolder.message.setText(index == 0 ? uploadListView.getInProgressTitle() :
                        uploadListView.getInQueueTitle());
                break;
            default: throw new RuntimeException("unknown view type " + viewType);
        }

        return convertView;
    }

    private static class ViewHolder {
        public TextView count;
        public TextView message;
        public TextView priority;
        public TextView stepDate;
        public TextView uploadDate;
        public TextView username;
    }
}
