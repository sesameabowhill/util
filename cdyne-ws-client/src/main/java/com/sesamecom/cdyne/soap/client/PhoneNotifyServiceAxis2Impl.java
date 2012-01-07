package com.sesamecom.cdyne.soap.client;

import com.cdyne.ws.notifyws.*;
import com.cdyne.ws.notifyws.GetQueueIDStatusDocument.GetQueueIDStatus;
import com.cdyne.ws.notifyws.GetTTSInULAWDocument.GetTTSInULAW;
import com.cdyne.ws.notifyws.NotifyPhoneAdvancedResponseDocument.NotifyPhoneAdvancedResponse;
import com.sesamecom.soap.generated.cdyne.PhoneNotifyStub;
import java.rmi.RemoteException;
import java.util.Calendar;

import org.apache.axis2.AxisFault;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * An AXIS 2 implementation of service PhoneNotifyAdvanced
 *
 */
public class PhoneNotifyServiceAxis2Impl implements PhoneNotifyService {
    private static final Logger log = LoggerFactory.getLogger(PhoneNotifyService.class);

    private static final String LICENSE_KEY_FOR_TEXT_TO_SAY = "164A072C-1199-4724-9227-22F61595544A";
    private static final String LICENSE_KEY_FOR_CALL = "F1A49B73-1B6D-4AA9-AF9A-D41FCFA08F89";

    @Override
    public long notifyPhoneAdvanced(
            String phoneNumberToDial,
            String transferNumber,
            int voiceId,
            String callerIdNumber,
            String callerIdName,
            String textToSay,
            int tryCount,
            int nextTryInSeconds,
            Calendar utcScheduledDateTime,
            short ttsRate,
            short ttsVolume,
            String statusChangePostUrl
    ) {

        long queueId = -1;
        try {
            PhoneNotifyStub stub = new PhoneNotifyStub();

            NotifyPhoneAdvancedDocument notifyPhoneAdvancedDocument =
                    NotifyPhoneAdvancedDocument.Factory.newInstance();
            NotifyPhoneAdvancedDocument.NotifyPhoneAdvanced req =
                    notifyPhoneAdvancedDocument.addNewNotifyPhoneAdvanced();

            AdvancedNotifyRequest anr = req.addNewAnr();
            anr.setPhoneNumberToDial(phoneNumberToDial);
            anr.setTransferNumber(transferNumber);
            anr.setVoiceID(voiceId);
            anr.setCallerIDNumber(callerIdNumber);
            anr.setCallerIDName(callerIdName);
            anr.setTextToSay(textToSay);
            anr.setLicenseKey(LICENSE_KEY_FOR_CALL);
            anr.setTryCount(tryCount);
            anr.setNextTryInSeconds(nextTryInSeconds);
            anr.setUTCScheduledDateTime(utcScheduledDateTime);
            anr.setTTSrate(ttsRate);
            anr.setTTSvolume(ttsVolume);
            anr.setStatusChangePostUrl(statusChangePostUrl);
            try {
                NotifyPhoneAdvancedResponseDocument notifyPhoneAdvancedResponseDocument =
                        stub.NotifyPhoneAdvanced(notifyPhoneAdvancedDocument);

                NotifyPhoneAdvancedResponse resp = notifyPhoneAdvancedResponseDocument.getNotifyPhoneAdvancedResponse();
                NotifyReturn retu = resp.getNotifyPhoneAdvancedResult();

                queueId = retu.getQueueID();

            } catch (RemoteException re) {
                log.error("error caught as remoteException", re);
            }
        } catch (AxisFault af) {
            log.warn("error caught as axisFault", af);
        }

        return queueId;
    }

    @Override
    public String getStatus(long queueId) {

        String status = null;
        try {
            PhoneNotifyStub stub = new PhoneNotifyStub();
            GetQueueIDStatusDocument req = GetQueueIDStatusDocument.Factory.newInstance();
            GetQueueIDStatus queueIdStatus = req.addNewGetQueueIDStatus();
            queueIdStatus.setQueueID(queueId);
            try {
                GetQueueIDStatusResponseDocument res = stub.GetQueueIDStatus(req);
                status = res.getGetQueueIDStatusResponse().getGetQueueIDStatusResult().getResponseText();
            } catch (RemoteException re) {
                log.error("error caught as remoteException", re);
            }
        } catch (AxisFault af) {
            log.warn("error caught as axisFault", af);
        }

        return status;
    }

    @Override
    public byte[] getTTSinULAW(String textToSay, int voiceId, short ttsRate, short ttsVolume) {
        byte[] ulaw = null;
        try {
            PhoneNotifyStub stub = new PhoneNotifyStub();
            GetTTSInULAWDocument reqDoc = GetTTSInULAWDocument.Factory.newInstance();
            GetTTSInULAW req = reqDoc.addNewGetTTSInULAW();
            req.setTextToSay(textToSay);
            req.setVoiceID(voiceId);
            req.setTTSrate(ttsRate);
            req.setTTSvolume(ttsVolume);
            req.setLicenseKey(LICENSE_KEY_FOR_TEXT_TO_SAY);
            try {
                GetTTSInULAWResponseDocument resDoc = stub.GetTTSInULAW(reqDoc);
                ulaw = resDoc.getGetTTSInULAWResponse().getGetTTSInULAWResult();
            } catch (RemoteException re) {
                log.error("error caught as remoteException", re);
            }
        } catch (AxisFault af) {
            log.warn("error caught as axisFault", af);
        }
        return ulaw;
    }

    @Override
    public byte[] getTTSinMP3(String textToSay, int voiceId, short ttsRate, short ttsVolume) {
        byte[] ulaw = null;
        try {
            PhoneNotifyStub stub = new PhoneNotifyStub();
            GetTTSInMP3Document reqDoc = GetTTSInMP3Document.Factory.newInstance();
            GetTTSInMP3Document.GetTTSInMP3 req = reqDoc.addNewGetTTSInMP3();
            req.setTextToSay(textToSay);
            req.setVoiceID(voiceId);
            req.setTTSrate(ttsRate);
            req.setTTSvolume(ttsVolume);
            req.setBitRate(32); // MP3 encoded in 32,64, or 128
            req.setLicenseKey(LICENSE_KEY_FOR_TEXT_TO_SAY);
            try {
                GetTTSInMP3ResponseDocument resDoc = stub.GetTTSInMP3(reqDoc);
                ulaw = resDoc.getGetTTSInMP3Response().getGetTTSInMP3Result();
            } catch (RemoteException re) {
                log.error("error caught as remoteException", re);
            }
        } catch (AxisFault af) {
            log.warn("error caught as axisFault", af);
        }
        return ulaw;
    }
}
