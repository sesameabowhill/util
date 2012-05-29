package com.sesamecom.android.sesameresponse;

/**
 * Created by Ivan
 */
public class ErrorResponse implements SesameApiResponse {
    final private String message;

    public ErrorResponse(String message) {
        this.message = message;
    }

    public String getMessage() {
        return message;
    }
}
