package com.sesamecom.android.model;

import android.content.IntentSender;

import java.util.*;

import static java.util.Collections.sort;

/**
 * Created by Ivan
 */
public class UploadListView {
    final public static String USERNAME = "username";
    final public static String PRIORITY = "priority";
    final public static String COUNT = "count";
    final public static String MESSAGE = "message";
    final public static String IN_PROGRESS = "in_progress";
    final public static String UPLOAD_STEP_DATE = "step_date";
    final public static String UPLOAD_START_DATE = "start_date";

    private LinkedList<Map<String, ?>> uploadView;
    private int inProgress;
    private int inQueue;

    public UploadListView() {
        uploadView = new LinkedList<Map<String, ?>>();
    }

    public List<Map<String, ?>> getUploadView() {
        return uploadView;
    }

    public void update(List<MemberUploadInfo> uploads) {
//        uploads = new ArrayList<MemberUploadInfo>();
//        uploads.add(new MemberUploadInfo(1, "povolny", true, new Date(112, 4, 29, 1, 14), new Date(), "Starting", 1));
//        uploads.add(new MemberUploadInfo(2, "mcfill1", false, new Date(), new Date(), "Waiting", 0));
//        uploads.add(new MemberUploadInfo(3, "mcfill2", false, new Date(), new Date(), "Waiting", 1));
//        uploads.add(new MemberUploadInfo(4, "mcfill3", false, new Date(), new Date(), "Waiting", 2));
//        uploads.add(new MemberUploadInfo(5, "appleortho", true, new Date(112, 4, 29, 1, 12), new Date(), "Rollback", 2));

        inProgress = 0;
        inQueue = 0;

        uploads = new ArrayList<MemberUploadInfo>(uploads);
        sort(uploads, byProcessOrder());

        Date now = new Date();
        uploadView.clear();
        int count = 0;
        for (MemberUploadInfo upload: uploads) {
            Map<String, Object> row = new HashMap<String, Object>();
            row.put(USERNAME, upload.getUsername());
            row.put(PRIORITY, priorityToString(upload.getPriority()));
            row.put(UPLOAD_START_DATE, diffBetweenDates(upload.getStart(), now));
            row.put(IN_PROGRESS, upload.isInProgress());
            row.put(COUNT, ++count);
            if (upload.isInProgress()) {
                row.put(UPLOAD_STEP_DATE, diffBetweenDates(upload.getUpdate(), now));
                row.put(MESSAGE, upload.getMessage());
                inProgress ++;
            } else {
                inQueue ++;
            }
            uploadView.add(row);
        }
    }

    public int getInProgress() {
        return inProgress;
    }

    public int getInQueue() {
        return inQueue;
    }

    private Comparator<MemberUploadInfo> byProcessOrder() {
        return new Comparator<MemberUploadInfo>() {
            @Override
            public int compare(MemberUploadInfo info1, MemberUploadInfo info2) {
                return chain(((Boolean) info2.isInProgress()).compareTo(info1.isInProgress()),
                        chain(((Integer)overridePriorityForInProgress(info2)).compareTo(overridePriorityForInProgress(info1)),
                                info1.getStart().compareTo(info2.getStart())));
            }
        };
    }

    private int overridePriorityForInProgress(MemberUploadInfo info) {
        return info.isInProgress() ? 0 : info.getPriority();
    }

    private static int chain(int first, int onEqual) {
        return first == 0 ? onEqual : first;
    }

    private static String priorityToString(int priority) {
        if (priority == 0) {
            return "large file";
        } else if (priority == 1) {
            return "small file";
        } else if (priority == 2) {
            return "important";
        } else {
            return "unknown #" + priority;
        }
    }

    private static String diffBetweenDates(Date start, Date end) {
        long seconds = (end.getTime() - start.getTime())/1000;
        return seconds >= 0 ? secondsToString(seconds) : "- " + secondsToString(- seconds);
    }

    private static String secondsToString(long time) {
        long seconds = time % 60;
        time /= 60;
        long minutes = time % 60;
        time /= 60;
        long hours = time % 24;
        time /= 24;
        long days = time;
        if (days > 0) {
            return days + "d " + hours + "h";
        } else if (hours > 0) {
            return hours + "h " + minutes + "m";
        } else if (minutes > 0) {
            return minutes + "m " + seconds + "s";
        } else {
            return seconds + "s";
        }
    }
}
