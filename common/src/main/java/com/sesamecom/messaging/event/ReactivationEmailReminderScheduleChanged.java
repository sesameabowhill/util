package com.sesamecom.messaging.event;


/**
 *
 */
final public class ReactivationEmailReminderScheduleChanged extends AbstractMemberEvent {

    @Deprecated // required for json serialization
    public ReactivationEmailReminderScheduleChanged() {
    }

    public ReactivationEmailReminderScheduleChanged(Integer memberId) {
        super(memberId);
    }



}
