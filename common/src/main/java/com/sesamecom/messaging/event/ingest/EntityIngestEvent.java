package com.sesamecom.messaging.event.ingest;

import com.sesamecom.messaging.event.MarshaledEvent;

import java.io.Serializable;

/**
 * Represents insert/update/delete event for individual entities.
 */
public class EntityIngestEvent extends MarshaledEvent implements Serializable {
    private EntityIngestAction action;
    private Integer memberId;
    private String id;

    public EntityIngestEvent() {
    }

    public EntityIngestEvent(Integer memberId, EntityIngestAction action, String id) {
        this.action = action;
        this.id = id;
        this.memberId = memberId;
    }

    public EntityIngestAction getAction() {
        return action;
    }

    public void setAction(EntityIngestAction action) {
        this.action = action;
    }

    public Integer getMemberId() {
        return memberId;
    }

    public void setMemberId(Integer memberId) {
        this.memberId = memberId;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }
}
