package com.sesamecom.messaging.event;


/**
 *
 */
final public class ReactivationEmailReminderScheduleChanged extends MemberSettingStatusChanged {

    public ReactivationEmailReminderScheduleChanged() {
    }

    public ReactivationEmailReminderScheduleChanged(Integer memberId) {
        super(memberId);
    }

}
