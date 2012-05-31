package com.sesamecom.android;

import android.content.ContextWrapper;
import android.content.SharedPreferences;

public class Settings {
    private static final String PREFERENCES_NAME = "defaults";
    private static final String PREFERENCE_USERNAME = "preference_username";
    private static final String PREFERENCE_PASSWORD = "preference_password";
    private static final String PREFERENCE_TIME_REFRESH = "preference_time_refresh";
    private static final String PREFERENCE_SERVER_REFRESH = "preference_server_refresh";

    private SharedPreferences sharedPreferences;

    public Settings(SharedPreferences sharedPreferences) {
        this.sharedPreferences = sharedPreferences;
    }

    public static Settings getFromContextWrapper(ContextWrapper contextWrapper) {
        return new Settings(contextWrapper.getSharedPreferences(PREFERENCES_NAME, Preferences.MODE_PRIVATE));
    }

    public void registerOnSharedPreferenceChangeListener(SharedPreferences.OnSharedPreferenceChangeListener listener) {
        sharedPreferences.registerOnSharedPreferenceChangeListener(listener);
    }

    public String getUsername() {
        return sharedPreferences.getString(PREFERENCE_USERNAME, "");
    }

    public String getPassword() {
        return sharedPreferences.getString(PREFERENCE_PASSWORD, "");
    }

    public int getTimeRefresh() {
        return toIntWithDefault(sharedPreferences.getString(PREFERENCE_TIME_REFRESH, ""), 5);
    }

    public int getServerRefresh() {
        return toIntWithDefault(sharedPreferences.getString(PREFERENCE_SERVER_REFRESH, ""), 60);
    }

    public static String getPreferencesName() {
        return PREFERENCES_NAME;
    }

    public static String getPrefNameUsername() {
        return PREFERENCE_USERNAME;
    }

    public static String getPrefNameTimeRefresh() {
        return PREFERENCE_TIME_REFRESH;
    }

    public static String getPrefNameServerRefresh() {
        return PREFERENCE_SERVER_REFRESH;
    }

    private static int toIntWithDefault(String string, int defaultValue) {
        try {
            return Integer.parseInt(string);
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

}