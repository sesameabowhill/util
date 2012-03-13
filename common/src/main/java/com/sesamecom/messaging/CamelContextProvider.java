package com.sesamecom.messaging;

import org.apache.camel.CamelContext;
import org.apache.camel.impl.DefaultCamelContext;

import javax.inject.Provider;
import javax.inject.Singleton;

@Singleton
public class CamelContextProvider implements Provider<CamelContext> {
    @Override
    @Singleton
    public CamelContext get() {
        CamelContext camelContext = new DefaultCamelContext();
        try {
            camelContext.addRoutes(new OutboundRouteBuilder());
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        return camelContext;
    }
}
