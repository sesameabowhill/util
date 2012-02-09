package com.sesamecom.messaging.event.injest;

import com.sesamecom.messaging.event.MarshaledEvent;
import com.sesamecom.messaging.event.MemberSettingStatusChanged;

/**
 * Indicates that initial upload occured, so all dependant events must be cleared out.
 * There is no efficient way to tell was exactly was changed during initial upload.
 */
final public class AllEntitiesAreWipedOutEvent extends MemberSettingStatusChanged {
    public AllEntitiesAreWipedOutEvent() {
    }

    public AllEntitiesAreWipedOutEvent(Integer memberId) {
        super(memberId);
    }
}
