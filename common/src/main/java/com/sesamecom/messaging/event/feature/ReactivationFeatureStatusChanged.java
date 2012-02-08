package com.sesamecom.messaging.event.feature;

/**
 *
 */
final public class ReactivationFeatureStatusChanged extends MemberFeatureStatusChanged {
    public ReactivationFeatureStatusChanged() {
    }

    public ReactivationFeatureStatusChanged(Integer memberId, Boolean enabled) {
        super(memberId, enabled);
    }
}
