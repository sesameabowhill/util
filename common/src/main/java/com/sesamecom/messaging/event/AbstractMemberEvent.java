package com.sesamecom.messaging.event;

import java.io.Serializable;

/**
 *
 */
public abstract class AbstractMemberEvent extends MarshaledEvent implements Serializable {
    private Integer memberId;

    @Deprecated // required for json serialization
    protected AbstractMemberEvent() {
    }

    protected AbstractMemberEvent(Integer memberId) {
        this.memberId = memberId;
    }

    public int getMemberId() {
        return memberId;
    }

    @Deprecated // required for json serialization
    public void setMemberId(int memberId) {
        this.memberId = memberId;
    }

}
