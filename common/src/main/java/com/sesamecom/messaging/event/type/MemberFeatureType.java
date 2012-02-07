package com.sesamecom.messaging.event.type;

/**
* Features available for member
*/
public enum MemberFeatureType {
    EmailReminders(1),
    EmailFinancialReminder(4),
    EmailFlexBenefitReminder(2),
    EmailPostAppointmentReminder(3),
    EmailReactivationReminder(33),
    EmailReminderCourtesy(30),
    HealthHistoryForm(5),
    Invisalign(6),
    MapWizard(7),
    OPSE(8),     // credit card payment
    OPSEAch(28), // patients can pay with check
    Orthomation(9),
    PatientReviews(29),
    PatientReviewsThirdParty(31),
    PMSHasPhoneType(19),
    PracticePromotionNewsletter(10),
    SIImageUpload(12),
    SIWeb(11),
    SMS(14),
    SurveyService(13),
    UIDental(20),
    UIOrtho(21),
    UIShowContractBalance(22),
    UIShowCurrentDue(23),
    UIShowInsuranceRemaining(26),
    UIShowRemainingBalance(24),
    UploadFixReferringNames(25), // ??
    Voice(15),
    VoiceFinancialReminder(18),
    VoiceFlexBenefitReminder(17),
    VoiceStandAlone(27),
    WebsiteAnalytics(32);

    private int id;

    MemberFeatureType(int id) {
        this.id = id;
    }

    public static MemberFeatureType findById(int id) {
        MemberFeatureType feature = null;
        for (MemberFeatureType f : MemberFeatureType.values()) {
            if (f.id == id)
                feature = f;
        }
        return feature;
    }

    public int getId() {
        return id;
    }
}
