package com.sesamecom.messaging;

import com.sesamecom.config.EnvironmentConfig;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.dataformat.JsonLibrary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static com.sesamecom.messaging.OutboundEndpoint.*;

/**
 * UntypedProducerActor doesn't seem to have an onRouteDefinition equivalent, so in order to marshal message bodies we
 * need to define outbound routes here.
 */
public class OutboundRouteBuilder extends RouteBuilder {
    private static final Logger log = LoggerFactory.getLogger(OutboundRouteBuilder.class);

    public void configure() throws Exception {
        createJsonRoute(OlapCommand.toCamelFormat(), EnvironmentConfig.getAnalyticsOlapAdHocCommandEndpoint());
        createJsonRoute(EtlCommand.toCamelFormat(), EnvironmentConfig.getAnalyticsEtlAdHocCommandEndpoint());
        createJsonRoute(SendSettingsChange.toCamelFormat(), EnvironmentConfig.getSendSettingsChangeEndpoint(Disabled.toCamelFormat()));
        createJsonRoute(IngestEvent.toCamelFormat(), EnvironmentConfig.getPmsUploadIngestEventEndpoint(Disabled.toCamelFormat()));
        from(Disabled.toCamelFormat()).stop();
    }
    
    private void createJsonRoute(String internal, String outbound) {
        log.info("outboundRoute->create internal: {}, outbound: {}",
            internal,
            outbound
        );

        from(internal)
            .marshal().json(JsonLibrary.Jackson)
            .to(outbound);
    }
}
