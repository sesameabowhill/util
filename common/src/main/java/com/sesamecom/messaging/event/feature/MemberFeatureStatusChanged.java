package com.sesamecom.messaging.event.feature;


import com.sesamecom.messaging.event.AbstractMemberEvent;

/**
 *
 */
public abstract class MemberFeatureStatusChanged extends AbstractMemberEvent {
    private Boolean enabled;

    @SuppressWarnings({"UnusedDeclaration", "deprecation"})
    @Deprecated // required for json serialization
    public MemberFeatureStatusChanged() {
    }

    public MemberFeatureStatusChanged(Integer memberId, Boolean enabled) {
        super(memberId);
        this.enabled = enabled;
    }

    public Boolean isEnabled() {
        return enabled;
    }

    @Deprecated // required for json serialization
    public void setEnabled(Boolean enabled) {
        this.enabled = enabled;
    }

}
