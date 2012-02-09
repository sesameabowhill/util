package com.sesamecom.messaging.event.injest;

import com.sesamecom.messaging.event.MarshaledEvent;

import java.io.Serializable;

/**
 * Represents insert/update/delete event for individual entities.
 */
public class EntityInjestEvent extends MarshaledEvent implements Serializable {
    private EntityInjestAction action;
    private Integer memberId;
    private String id;

    public EntityInjestEvent() {
    }

    public EntityInjestEvent(Integer memberId, EntityInjestAction action, String id) {
        this.action = action;
        this.id = id;
        this.memberId = memberId;
    }

    public EntityInjestAction getAction() {
        return action;
    }

    public void setAction(EntityInjestAction action) {
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
