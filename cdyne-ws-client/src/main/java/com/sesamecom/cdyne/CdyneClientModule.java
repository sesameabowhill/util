package com.sesamecom.cdyne;

import com.sesamecom.cdyne.soap.client.PhoneNotifyService;
import com.sesamecom.cdyne.soap.client.PhoneNotifyServiceAxis2Impl;
import com.google.inject.AbstractModule;

public class CdyneClientModule extends AbstractModule {

    @Override
    protected void configure() {
        bind(PhoneNotifyService.class).to(PhoneNotifyServiceAxis2Impl.class);
    }
}
