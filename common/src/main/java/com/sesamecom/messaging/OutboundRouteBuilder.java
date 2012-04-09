package com.sesamecom.messaging;

import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.dataformat.JsonLibrary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static com.sesamecom.config.EnvironmentConfig.*;
import static com.sesamecom.messaging.OutboundEndpoint.*;

/**
 * UntypedProducerActor doesn't seem to have an onRouteDefinition equivalent, so in order to marshal message bodies we
 * need to define outbound routes here.
 */
public class OutboundRouteBuilder extends RouteBuilder {
    private static final Logger log = LoggerFactory.getLogger(OutboundRouteBuilder.class);
    private static final String disabled = Disabled.toCamelFormat();

    public void configure() throws Exception {
        createJsonRoute(OlapCommand, getAnalyticsOlapAdHocCommandEndpoint(disabled));
        createJsonRoute(EtlCommand, getAnalyticsEtlAdHocCommandEndpoint(disabled));
        createJsonRoute(SendSettingsChange, getSendSettingsChangeEndpoint(disabled));
        createJsonRoute(IngestEvent, getPmsUploadIngestEventEndpoint(disabled));
        createJsonRoute(ReinitialEvent, getReinitialEndpoint(disabled));
        createJsonRoute(JanitorCleanup, getJanitorCleanupTaskEndpoint(disabled));
        from(disabled).stop();
    }
    
    private void createJsonRoute(OutboundEndpoint internal, String outbound) {
        log.info("outboundRoute->create internal: {}, outbound: {}",
            internal.toCamelFormat(),
            outbound
        );

        from(internal.toCamelFormat())
            .marshal().json(JsonLibrary.Jackson)
            .to(outbound);
    }
}
