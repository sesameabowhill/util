package com.sesamecom.cdyne.soap.client;

/**
 * Defines an interface for calling the CDYNE PhoneNotify Web Services
 */
public interface PhoneNotifyService {

    /**
     * This Method will call any phone number in the US/Canada and read the TextToSay to that phone number.
     * Set VoiceID equal to 0 for TTS Diane to speak the Text. For a list of Voices with their ID look at getVoices.
     * PhoneNumberToDial and CallerID must be filled in (They can be in any format as long as there is 10 digits).
     * 
     * PhoneNotifyAdvanced allows you to control the notifies with a class. This allows for the maximum combinations
     * of using notify.
     * @return queueId
     */
    public long notifyPhoneAdvanced(
            String phoneNumberToDial,
            String transferNumber,
            int voiceId,
            String callerIdNumber,
            String callerIdName,
            String textToSay,
            String licenceKey,
            int tryCount,
            int nextTryInSeconds,
            java.util.Calendar utcScheduledDateTime,
            short ttsRate,
            short ttsVolume,
            String statusChangePostUrl
            );

    /**
     * Calls GetQueueIDStatus, which returns a status on a particular QueueID.
     * 
     * @param queueId
     * @return the current responseText associated with the queueId
     */
    public String getStatus(long queueId);

    /**
     * Calls GetTTSInULAW, which allows you to convert text into a ULAW encoded sound file.
     * (May require an additional License Key)
     *
     *  @param textToSay
     *  @param voiceID
     *  @param ttsRate
     *  @param ttsVolume
     *  @param licenseKey
     * @return ULAW encoded sound file
     */
    public byte[] getTTSinULAW(String textToSay, int voiceId, short ttsRate, short ttsVolume, String licenseKey);
}

