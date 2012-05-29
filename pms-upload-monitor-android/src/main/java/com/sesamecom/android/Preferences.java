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
        Preference preferenceUsername = getPreferenceManager().findPreference("preference_username");
        preferenceUsername.setOnPreferenceChangeListener(new Preference.OnPreferenceChangeListener() {
            @Override
            public boolean onPreferenceChange(Preference preference, Object newUsername) {
                preference.setSummary(newUsername.toString());
                return true;
            }
        });
        Settings settings = Settings.getFromContextWrapper(this);
        preferenceUsername.setSummary(settings.getUsername());
    }

}
