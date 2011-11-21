package com.sesamecom.common;

/**
 * Thrown when attempting to access a required configuration property that isn't defined.
 */
public class ConfigPropertyMissingException extends RuntimeException {
    public ConfigPropertyMissingException(String fileTried, String propertyName) {
        super(String.format(
            "Required property '%s' not defined.  Tried system properties and file at '%s'.",
            propertyName,
            fileTried
        ));
    }
}
