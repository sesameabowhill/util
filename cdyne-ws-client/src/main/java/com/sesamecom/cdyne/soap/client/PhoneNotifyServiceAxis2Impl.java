package com.sesamecom.cdyne.soap.client;

import com.cdyne.ws.notifyws.AdvancedNotifyRequest;
import com.cdyne.ws.notifyws.GetQueueIDStatusDocument;
import com.cdyne.ws.notifyws.GetQueueIDStatusDocument.GetQueueIDStatus;
import com.cdyne.ws.notifyws.GetQueueIDStatusResponseDocument;
import com.cdyne.ws.notifyws.NotifyPhoneAdvancedDocument;
import com.cdyne.ws.notifyws.NotifyPhoneAdvancedResponseDocument;
import com.cdyne.ws.notifyws.NotifyPhoneAdvancedResponseDocument.NotifyPhoneAdvancedResponse;
import com.cdyne.ws.notifyws.NotifyReturn;
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
public class PhoneNotifyServiceAxis2Impl implements PhoneNotifyService
{

    private static final Logger log = LoggerFactory.getLogger(PhoneNotifyService.class);

    @Override
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
            anr.setLicenseKey(licenceKey);
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
}
