package com.sesamecom.protocols;

/**
 * Exception if you get things mixed up creating a custom url protocol
 */
public class CustomUrlHandlerException extends RuntimeException {
    public CustomUrlHandlerException(String msg) {
        super(msg);
    }
}