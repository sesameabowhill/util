package com.sesamecom.messaging.event.type;

/**
* Email Reminder Setting types
*/
public enum EmailReminderSettingType {
    appointment_first("Appointment Reminder"),
    appointment_second("Appointment Reminder"),
    benefit("Dental Plan Benefits Expiring", "Ortho Plan Benefits Expiring"),
    courtesy("Appointment Reminder"),
    custom("From Your Dentist", "From Your Orthodontist"),
    financial("Financial Reminder"),
    flex("Flex Spending Plan Expiring"),
    noshow("We Missed You!"),
    post_appointment("We'd Like Your Feedback"),
    reactivation_first(""),
    reactivation_second(""),
    reactivation_third(""),
    recall("Dental Checkup Reminder", "Appointment Reminder"),
    referral(""),
    standard("From Your Dentist", "From Your Orthodontist"),
    welcome("Welcome!");

    final String descriptionDental;
    final String descriptionOrtho;

    EmailReminderSettingType(String desc) {
        this.descriptionDental = desc;
        this.descriptionOrtho = desc;
    }

    EmailReminderSettingType(String descDental, String descOrtho) {
        this.descriptionDental = descDental;
        this.descriptionOrtho = descOrtho;
    }

    // TODO should be moved to representation level (DefaultEmailMessage)
    @Deprecated
    public String getDescriptionDental() {
        return descriptionDental;
    }

    // TODO should be moved to representation level (DefaultEmailMessage)
    @Deprecated
    public String getDescriptionOrtho() {
        return descriptionOrtho;
    }
}
