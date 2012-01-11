package com.sesamecom.cdyne.soap.client;

/**
 * Defines an interface for calling the CDYNE SMSNotify Web Services
 */
public interface SmsNotifyService {

    public String simpleSmsSendWithPostback (String phoneNumber, String message, String postbackUrl);

    /**
     * Calls GetMessageStatus, which returns a status on a particular QueueID.
     *
     * @param guid
     * @return the current responseText associated with the queueId
     */
    public String getStatus(long guid);
}
