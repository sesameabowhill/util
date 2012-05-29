package com.sesamecom.android.model;

import com.google.gson.annotations.SerializedName;

import java.util.Date;

/**
 * Created by Ivan
 */
public class MemberUploadInfo {
    @SerializedName("i")
    private int clientId;
    @SerializedName("u")
    private String username;
    @SerializedName("a")
    private boolean isInProgress;
    @SerializedName("s")
    private Date start;
    @SerializedName("c")
    private Date update;
    @SerializedName("m")
    private String message;
    @SerializedName("p")
    private int priority;

    public MemberUploadInfo() {
    }

    public MemberUploadInfo(int clientId, String username, boolean inProgress, Date start, Date update, String message, int priority) {
        this.clientId = clientId;
        this.username = username;
        isInProgress = inProgress;
        this.start = start;
        this.update = update;
        this.message = message;
        this.priority = priority;
    }

    public int getClientId() {
        return clientId;
    }

    public String getUsername() {
        return username;
    }

    public boolean isInProgress() {
        return isInProgress;
    }

    public Date getStart() {
        return start;
    }

    public Date getUpdate() {
        return update;
    }

    public String getMessage() {
        return message;
    }

    public int getPriority() {
        return priority;
    }
}
