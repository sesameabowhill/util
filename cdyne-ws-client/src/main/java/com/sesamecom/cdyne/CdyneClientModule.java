package com.sesamecom.cdyne;

import com.cdyne.sms2.SMSRequest;
import com.cdyne.sms2.impl.SMSRequestImpl;
import com.sesamecom.cdyne.soap.client.PhoneNotifyService;
import com.sesamecom.cdyne.soap.client.PhoneNotifyServiceAxis2Impl;
import com.google.inject.AbstractModule;
import com.sesamecom.cdyne.soap.client.SmsNotifyService;
import com.sesamecom.cdyne.soap.client.SmsNotifyServiceAxis2Impl;

public class CdyneClientModule extends AbstractModule {
    @Override
    protected void configure() {
        bind(PhoneNotifyService.class).to(PhoneNotifyServiceAxis2Impl.class);
        bind(SmsNotifyService.class).to(SmsNotifyServiceAxis2Impl.class);
    }
}
