package com.sesamecom.messaging.event.janitor;

import com.sesamecom.messaging.event.MarshaledEvent;

/**
 * Command to send on janitorCleanupTaskEndpoint to initiate cleanup of all member data prior to but not including a
 * given version id, which should be the id of the last initial ingested for the practice.
 */
public class ReinitialCleanupCommand extends MarshaledEvent {
    private Integer clientId;
    private Integer upToVersionId;

    public ReinitialCleanupCommand() {
    }

    public ReinitialCleanupCommand(Integer clientId, Integer upToVersionId) {
        this.clientId = clientId;
        this.upToVersionId = upToVersionId;
    }

    public Integer getClientId() {
        return clientId;
    }

    public Integer getUpToVersionId() {
        return upToVersionId;
    }

    public void setClientId(Integer clientId) {
        this.clientId = clientId;
    }

    public void setUpToVersionId(Integer upToVersionId) {
        this.upToVersionId = upToVersionId;
    }
}
