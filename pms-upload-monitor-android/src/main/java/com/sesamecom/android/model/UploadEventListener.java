package com.sesamecom.android.model;

/**
 * Created by Ivan
 */
public interface UploadEventListener {
    void processStarted(String username);
    void processComplete(String username);
}
