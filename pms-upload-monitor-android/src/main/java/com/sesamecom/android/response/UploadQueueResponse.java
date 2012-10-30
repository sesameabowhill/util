package com.sesamecom.android.response;

import com.sesamecom.android.model.MemberUploadInfo;

import java.util.List;

/**
 * Created by Ivan
 */
public class UploadQueueResponse implements SesameApiResponse {
    final private List<MemberUploadInfo> uploads;

    public UploadQueueResponse(List<MemberUploadInfo> uploads) {
        this.uploads = uploads;
    }

    public List<MemberUploadInfo> getUploads() {
        return uploads;
    }
}
