package com.sesamecom.messaging;

/**
 *
 */
public enum OutboundEndpoint {
    OlapCommand("direct:olapAdHocCommandOutboundEndpoint"),
    EtlCommand("direct:etlAdHocCommandOutboundEndpoint"),
    SendSettingsChange("direct:sendSettingsChangeOutboundEndpoint"),
    IngestEvent("direct:ingestEventOutboundEndpoint"),
    ReinitialEvent("direct:reinitialEndpoint"),
    JanitorCleanup("direct:janitorCleanup"),
    Disabled("direct:disabled");

    private String endpoint;

    private OutboundEndpoint(String endpoint) {
        this.endpoint = endpoint;
    }

    public String toCamelFormat() {
        return endpoint;
    }
}
