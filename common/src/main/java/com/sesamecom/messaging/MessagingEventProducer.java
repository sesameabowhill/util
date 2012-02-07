package com.sesamecom.messaging;

import com.sesamecom.messaging.event.MarshaledEvent;
import org.apache.camel.CamelContext;
import org.apache.camel.ProducerTemplate;

import javax.inject.Inject;

/**
 *
 */
public class MessagingEventProducer {
    private final ProducerTemplate producer;

    @Inject
    public MessagingEventProducer(CamelContext camelContext) {
        producer = camelContext.createProducerTemplate();
    }

    public void sendEvent(OutboundEndpoint endpoint, MarshaledEvent event) {
        producer.sendBody(endpoint.toCamelFormat(), event);
    }
}
