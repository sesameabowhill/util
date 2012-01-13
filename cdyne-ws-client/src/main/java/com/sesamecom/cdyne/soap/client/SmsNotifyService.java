package com.sesamecom.cdyne.soap.client;

/**
 * Defines an interface for calling the CDYNE SMSNotify Web Services
 */
public interface SmsNotifyService {

    /**
     * This method calls CDYNE's SimpleSMSWithPostback method, will send out a text message to
     * the phone number specified.
     * @param phoneNumber
     * @param message
     * @param postbackUrl
     * @return
     */
    public String simpleSmsSendWithPostback (String phoneNumber, String message, String postbackUrl);

    /**
     * Calls GetMessageStatus, which returns a status on a particular QueueID.
     *
     * @param guid
     * @return the current responseText associated with the queueId
     */
    public String getStatus(long guid);
}
