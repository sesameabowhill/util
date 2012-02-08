package com.sesamecom.messaging.event;


import com.sesamecom.messaging.event.type.EmailReminderSettingType;

/**
 *
 */
final public class EmailReminderScheduleChanged extends MemberSettingStatusChanged {
    private EmailReminderSettingType settingType;

    public EmailReminderScheduleChanged() {
    }

    public EmailReminderScheduleChanged(Integer memberId, EmailReminderSettingType settingType) {
        super(memberId);
        this.settingType = settingType;
    }

    public EmailReminderSettingType getSettingType() {
        return settingType;
    }

    public void setSettingType(EmailReminderSettingType type) {
        this.settingType = type;
    }
}
