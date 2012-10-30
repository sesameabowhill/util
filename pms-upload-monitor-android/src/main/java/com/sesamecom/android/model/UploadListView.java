package com.sesamecom.android.model;

import android.content.IntentSender;

import java.util.*;

import static java.util.Collections.sort;

/**
 * Created by Ivan
 */
public class UploadListView {

    private List<MemberUploadInfo> uploadsInQueue;
    private List<MemberUploadInfo> uploadsInProgress;

    public UploadListView() {
        uploadsInProgress = new ArrayList<MemberUploadInfo>();
        uploadsInQueue = new ArrayList<MemberUploadInfo>();
    }

    public void update(List<MemberUploadInfo> uploads) {
//        uploads = new ArrayList<MemberUploadInfo>();
//        uploads.add(new MemberUploadInfo(1, "povolny", true, new Date(112, 4, 29, 1, 14), new Date(), "Starting", 1));
//        uploads.add(new MemberUploadInfo(2, "mcfill1", false, new Date(), new Date(), "Waiting", 0));
//        uploads.add(new MemberUploadInfo(3, "mcfill2", false, new Date(), new Date(), "Waiting", 1));
//        uploads.add(new MemberUploadInfo(4, "mcfill3", false, new Date(), new Date(), "Waiting", 2));
//        uploads.add(new MemberUploadInfo(5, "appleortho", true, new Date(112, 4, 29, 1, 12), new Date(), "Rollback", 2));

        uploads = new ArrayList<MemberUploadInfo>(uploads);
        sort(uploads, byProcessOrder());
        uploadsInProgress.clear();
        uploadsInQueue.clear();
        for (MemberUploadInfo upload: uploads) {
            if (upload.isInProgress()) {
                uploadsInProgress.add(upload);
            } else {
                uploadsInQueue.add(upload);
            }
        }
    }

    public int getInProgressSize() {
        return uploadsInProgress.size();
    }

    public int getInQueueSize() {
        return uploadsInQueue.size();
    }

    public MemberUploadInfo getInProgress(int index) {
        return uploadsInProgress.get(index);
    }

    public MemberUploadInfo getInQueue(int index) {
        return uploadsInQueue.get(index);
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

    public static String priorityToString(int priority) {
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

    public static String diffBetweenDates(Date start, Date end) {
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

    public String getInProgressTitle() {
        if (getInProgressSize() == 0) {
            return "No uploads are in Progress";
        } else if (getInProgressSize() == 1) {
            return "1 upload is in Progress";
        } else {
            return getInProgressSize() + " uploads are in Progress";
        }
    }

    public String getInQueueTitle() {
        if (getInQueueSize() == 0) {
            return "No uploads are in Queue";
        } else if (getInQueueSize() == 1) {
            return "1 upload is in Queue";
        } else {
            return getInQueueSize() + " uploads are in Queue";
        }
    }

}
