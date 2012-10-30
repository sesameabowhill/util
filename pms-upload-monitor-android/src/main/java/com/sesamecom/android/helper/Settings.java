package com.sesamecom.android.helper;

import android.content.ContextWrapper;
import android.content.SharedPreferences;
import com.sesamecom.android.Preferences;

public class Settings {
    private static final String PREFERENCES_NAME = "defaults";

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
        return sharedPreferences.getString(Key.Username.getPrefName(), "");
    }

    public String getPassword() {
        return sharedPreferences.getString(Key.Password.getPrefName(), "");
    }

    public int getRedrawInterval() {
        return getIntervalValue(Key.RedrawInterval);
    }

    public int getUploadListReloadInterval() {
        return getIntervalValue(Key.UploadListReloadInterval);
    }

    public int getIntervalValue(Key key) {
        int defaultValue;
        switch (key) {
            case RedrawInterval:
                defaultValue = 5;
                break;
            case UploadListReloadInterval:
                defaultValue = 60;
                break;
            default:
                throw new RuntimeException("key [" + key + "] is not interval");
        }
        return toIntWithDefault(sharedPreferences.getString(key.getPrefName(), ""), defaultValue);
    }

    public static String getPreferencesName() {
        return PREFERENCES_NAME;
    }

    private static int toIntWithDefault(String string, int defaultValue) {
        try {
            return Integer.parseInt(string);
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public enum Key {
        Username("preference_username"),
        Password("preference_password"),
        RedrawInterval("preference_time_refresh"),
        UploadListReloadInterval("preference_server_refresh");

        private String prefName;

        private Key(String prefName) {
            this.prefName = prefName;
        }

        public String getPrefName() {
            return prefName;
        }
    }

}