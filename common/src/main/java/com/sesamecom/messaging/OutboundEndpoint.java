package com.sesamecom.messaging;

/**
 *
 */
public enum OutboundEndpoint {
    OlapCommand("direct:olapAdHocCommandOutboundEndpoint"),
    EtlCommand("direct:etlAdHocCommandOutboundEndpoint"),
    SendSettingsChange("direct:sendSettingsChangeOutboundEndpoint"),
    IngestEvent("direct:ingestEventOutboundEndpoint"),
    Disabled("direct:disabled");
    
    private String endpoint;

    private OutboundEndpoint(String endpoint) {
        this.endpoint = endpoint;
    }

    public String toCamelFormat() {
        return endpoint;
    }
}
