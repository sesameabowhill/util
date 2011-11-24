package com.sesamecom.common;

/**
 * Thrown when attempting to access a required configuration property that isn't defined.
 */
public class ConfigPropertyMissingException extends RuntimeException {
    public ConfigPropertyMissingException(String propertyName, String fileTried) {
        super(String.format(
            "Required property '%s' not defined.  Tried system properties %s.",
            propertyName,
            fileTried == null ? "only (no sesameConfigurationFile specified)" : "and file at " + fileTried
        ));
    }
}
