package com.sesamecom.messaging;

import com.sesamecom.config.EnvironmentConfig;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.dataformat.JsonLibrary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * UntypedProducerActor doesn't seem to have an onRouteDefinition equivalent, so in order to marshal message bodies we
 * need to define outbound routes here.
 */
public class OutboundRouteBuilder extends RouteBuilder {
    private static final Logger log = LoggerFactory.getLogger(OutboundRouteBuilder.class);

//    public static final String OLAP_COMMAND_OUTBOUND_ENDPOINT = "direct:olapAdHocCommandOutboundEndpoint";
//    public static final String ETL_COMMAND_OUTBOUND_ENDPOINT = "direct:etlAdHocCommandOutboundEndpoint";
//    public static final String SEND_SETTINGS_CHANGE_OUTBOUND_ENDPOINT = "direct:sendSettingsChangeOutboundEndpoint";
//    public static final String INJEST_EVENT_OUTBOUND_ENDPOINT = "direct:injestEventOutboundEndpoint";
    private static final String DISABLED = "direct:disabled";

    public void configure() throws Exception {
        createJsonRoute(OutboundEndpoint.OlapCommand.toCamelFormat(), EnvironmentConfig.getAnalyticsOlapAdHocCommandEndpoint());
        createJsonRoute(OutboundEndpoint.EtlCommand.toCamelFormat(), EnvironmentConfig.getAnalyticsEtlAdHocCommandEndpoint());
        createJsonRoute(OutboundEndpoint.SendSettingsChange.toCamelFormat(), EnvironmentConfig.getSendSettingsChangeEndpoint(DISABLED));
        createJsonRoute(OutboundEndpoint.InjestEvent.toCamelFormat(), EnvironmentConfig.getPmsUploadInjectEventEndpoint(DISABLED));
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
