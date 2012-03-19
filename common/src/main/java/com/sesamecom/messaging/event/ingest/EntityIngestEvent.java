package com.sesamecom.messaging.event.ingest;

import com.sesamecom.messaging.event.AbstractMemberEvent;
import com.sesamecom.messaging.event.MarshaledEvent;

import java.io.Serializable;

/**
 * Represents insert/update/delete event for individual entities.
 */
public abstract class EntityIngestEvent extends AbstractMemberEvent implements Serializable {
    private EntityIngestAction action;
    private String id;

    @SuppressWarnings({"UnusedDeclaration", "deprecation"})
    @Deprecated // required for json serialization
    public EntityIngestEvent() {
    }

    public EntityIngestEvent(Integer memberId, EntityIngestAction action, String id) {
        super(memberId);
        this.action = action;
        this.id = id;
    }

    public EntityIngestAction getAction() {
        return action;
    }

    @Deprecated // required for json serialization
    public void setAction(EntityIngestAction action) {
        this.action = action;
    }

    public String getId() {
        return id;
    }

    @Deprecated // required for json serialization
    public void setId(String id) {
        this.id = id;
    }
}
