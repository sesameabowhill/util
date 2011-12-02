package com.sesamecom.config;

public class BadConfigPropertyValueException extends RuntimeException {
    public BadConfigPropertyValueException(String message, Throwable cause) {
        super(message, cause);
    }
}
