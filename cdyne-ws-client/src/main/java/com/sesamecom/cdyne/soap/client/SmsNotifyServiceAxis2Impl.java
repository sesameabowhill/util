package com.sesamecom.cdyne.soap.client;

import com.cdyne.sms2.*;
import com.cdyne.sms2.impl.SMSRequestImpl;
import com.microsoft.schemas._2003._10.serialization.arrays.impl.ArrayOfstringImpl;
import com.sesamecom.soap.generated.cdyne.SmsStub;
import org.apache.axis2.AxisFault;
import org.apache.axis2.client.ServiceClient;
import org.datacontract.schemas._2004._07.smsws.SMSAdvancedRequestDocument;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.rmi.RemoteException;

public class SmsNotifyServiceAxis2Impl implements SmsNotifyService {
    private static final Logger log = LoggerFactory.getLogger(SmsNotifyService.class);
    
    private static final String SMS_LICENSE_KEY = "97050845-77d1-450b-9c14-3f813b86754c";

    @Override
    public String simpleSmsSendWithPostback(String phoneNumber, String message, String postbackUrl) {
        String messageId = "";

        try {
            SmsStub smsStub = new SmsStub();
            ServiceClient sc = smsStub._getServiceClient();
            sc.engageModule("addressing");
            
            SimpleSMSsendWithPostbackDocument sspd = SimpleSMSsendWithPostbackDocument.Factory.newInstance();
            SimpleSMSsendWithPostbackDocument.SimpleSMSsendWithPostback simpleSMSsendWithPostback = 
                    sspd.addNewSimpleSMSsendWithPostback();
            
            simpleSMSsendWithPostback.setPhoneNumber(phoneNumber);
            simpleSMSsendWithPostback.setLicenseKey(SMS_LICENSE_KEY);
            simpleSMSsendWithPostback.setMessage(message);
            simpleSMSsendWithPostback.setStatusPostBackURL(postbackUrl);

            try {
                SimpleSMSsendWithPostbackResponseDocument responseDocument =
                        smsStub.SimpleSMSsendWithPostback(sspd);

                SimpleSMSsendWithPostbackResponseDocument.SimpleSMSsendWithPostbackResponse simpleSMSsendWithPostbackResponse =
                        responseDocument.getSimpleSMSsendWithPostbackResponse();

                SMSResponse response = simpleSMSsendWithPostbackResponse.getSimpleSMSsendWithPostbackResult();
                messageId = response.getMessageID();
            } catch (RemoteException e) {
                log.error("Unable to get CDYNE SMS response", e);
            }

        } catch (AxisFault e) {
            log.warn("error caught as axisFault", e);
        }
        return messageId;
    }

    @Override
    public String getStatus(long guid) {
        return null;
    }
}
