package com.sesamecom.messaging.event;


import com.sesamecom.messaging.event.type.MemberFeatureType;

/**
 *
 */
final public class MemberFeatureStatusChanged extends MemberSettingStatusChanged {
    private MemberFeatureType featureType;
    private Boolean enabled;

    public MemberFeatureStatusChanged() {
    }

    public MemberFeatureStatusChanged(Integer memberId, MemberFeatureType featureType, Boolean enabled) {
        super(memberId);
        this.enabled = enabled;
        this.featureType = featureType;
    }

    public MemberFeatureType getFeatureType() {
        return featureType;
    }

    public void setFeatureType(MemberFeatureType featureType) {
        this.featureType = featureType;
    }

    public Boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(Boolean enabled) {
        this.enabled = enabled;
    }
}
