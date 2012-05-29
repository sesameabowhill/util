package com.sesamecom.android;

import android.content.ContextWrapper;
import android.content.SharedPreferences;

public class Settings {
    private static final String PREFERENCES_NAME = "defaults";
    private static final String PREFERENCE_USERNAME = "preference_username";
    private static final String PREFERENCE_PASSWORD = "preference_password";

    private SharedPreferences sharedPreferences;

    public Settings(SharedPreferences sharedPreferences) {
        this.sharedPreferences = sharedPreferences;
    }

    public static Settings getFromContextWrapper(ContextWrapper contextWrapper) {
        return new Settings(contextWrapper.getSharedPreferences(PREFERENCES_NAME, Preferences.MODE_PRIVATE));
    }

    public String getUsername() {
        return sharedPreferences.getString(PREFERENCE_USERNAME, "");
    }

    public String getPassword() {
        return sharedPreferences.getString(PREFERENCE_PASSWORD, "");
    }

    public static String getPreferencesName() {
        return PREFERENCES_NAME;
    }
}