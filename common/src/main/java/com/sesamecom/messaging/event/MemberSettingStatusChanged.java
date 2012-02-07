package com.sesamecom.messaging.event;

import java.io.Serializable;

/**
 *
 */
public abstract class MemberSettingStatusChanged extends MarshaledEvent implements Serializable {
    private Integer memberId;

    protected MemberSettingStatusChanged() {
    }

    protected MemberSettingStatusChanged(Integer memberId) {
        this.memberId = memberId;
    }

    public int getMemberId() {
        return memberId;
    }

    public void setMemberId(int memberId) {
        this.memberId = memberId;
    }

}
