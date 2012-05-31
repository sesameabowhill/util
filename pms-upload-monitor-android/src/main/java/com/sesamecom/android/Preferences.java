package com.sesamecom.android;

import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceActivity;

/**
 * Created by Ivan
 */
public class Preferences extends PreferenceActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getPreferenceManager().setSharedPreferencesName(Settings.getPreferencesName());
        addPreferencesFromResource(R.xml.preferences);

        Preference preferenceUsername = getPreferenceManager().findPreference(Settings.getPrefNameUsername());
        preferenceUsername.setOnPreferenceChangeListener(new Preference.OnPreferenceChangeListener() {
            @Override
            public boolean onPreferenceChange(Preference preference, Object newUsername) {
                preference.setSummary(newUsername.toString());
                return true;
            }
        });

        Preference preferenceTimeRefresh = getPreferenceManager().findPreference(Settings.getPrefNameTimeRefresh());
        preferenceTimeRefresh.setOnPreferenceChangeListener(new Preference.OnPreferenceChangeListener() {
            @Override
            public boolean onPreferenceChange(Preference preference, Object newTimeRefresh) {
                preference.setSummary(intervalToString((String) newTimeRefresh));
                return true;
            }
        });

        Preference preferenceServerRefresh = getPreferenceManager().findPreference(Settings.getPrefNameServerRefresh());
        preferenceServerRefresh.setOnPreferenceChangeListener(new Preference.OnPreferenceChangeListener() {
            @Override
            public boolean onPreferenceChange(Preference preference, Object newServerRefresh) {
                preference.setSummary(intervalToString((String) newServerRefresh));
                return true;
            }
        });

        Settings settings = Settings.getFromContextWrapper(this);
        preferenceUsername.setSummary(settings.getUsername());
        preferenceTimeRefresh.setSummary(intervalToString(settings.getTimeRefresh()));
        preferenceServerRefresh.setSummary(intervalToString(settings.getServerRefresh()));
    }

    private static String intervalToString(String seconds) {
        try {
            return intervalToString(Integer.parseInt(seconds));
        } catch (NumberFormatException e) {
            return intervalToString(0);
        }
    }

    private static String intervalToString(int seconds) {
        switch (seconds) {
            case 0:
                return "Disabled";
            case 60:
                return "Every minute";
            case 5*60:
                return "Every 5 minutes";
            default:
                return "Every " + (seconds == 1 ? "second" : seconds + " seconds");
        }
    }

}
