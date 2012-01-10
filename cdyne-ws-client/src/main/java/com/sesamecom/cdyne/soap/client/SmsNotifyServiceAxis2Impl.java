package com.sesamecom.cdyne.soap.client;

import com.cdyne.sms2.SMSRequest;
import com.cdyne.sms2.SMSRequestDocument;
import com.cdyne.sms2.SimpleSMSsendDocument;
import com.cdyne.sms2.SimpleSMSsendWithPostbackDocument;
import com.cdyne.sms2.impl.SMSRequestImpl;
import com.microsoft.schemas._2003._10.serialization.arrays.impl.ArrayOfstringImpl;
import com.sesamecom.soap.generated.cdyne.SmsStub;
import org.apache.axis2.AxisFault;
import org.datacontract.schemas._2004._07.smsws.SMSAdvancedRequestDocument;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SmsNotifyServiceAxis2Impl implements SmsNotifyService {
    private static final Logger log = LoggerFactory.getLogger(SmsNotifyService.class);

    @Override
    public long simpleSmsSendWithPostback(String phoneNumber, String licenseKey, String message, String postbackUrl) {
        long queueId = -1;
        try {
            SmsStub smsStub = new SmsStub();

        } catch (AxisFault e) {
            log.warn("error caught as axisFault", e);
        }
        return queueId;
    }

    @Override
    public String getStatus(long guid) {
        return null;
    }
}
