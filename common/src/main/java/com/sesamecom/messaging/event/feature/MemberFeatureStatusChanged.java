package com.sesamecom.messaging.event.feature;


import com.sesamecom.messaging.event.MemberSettingStatusChanged;

/**
 *
 */
public class MemberFeatureStatusChanged extends MemberSettingStatusChanged {
    private Boolean enabled;

    public MemberFeatureStatusChanged() {
    }

    public MemberFeatureStatusChanged(Integer memberId, Boolean enabled) {
        super(memberId);
        this.enabled = enabled;
    }

    public Boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(Boolean enabled) {
        this.enabled = enabled;
    }
}
