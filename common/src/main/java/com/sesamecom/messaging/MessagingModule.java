package com.sesamecom.messaging;

import com.google.inject.AbstractModule;
import org.apache.camel.CamelContext;

import javax.inject.Singleton;

/**
 *
 */
public class MessagingModule extends AbstractModule {
    @Override
    protected void configure() {
        bind(CamelContext.class).toProvider(CamelContextProvider.class)
            .in(Singleton.class);
    }
}
