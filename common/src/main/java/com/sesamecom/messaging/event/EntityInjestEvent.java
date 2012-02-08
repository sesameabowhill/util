package com.sesamecom.messaging.event;

import com.sesamecom.messaging.event.type.EntityInjectAction;
import com.sesamecom.messaging.event.type.InjestedEntity;

import java.io.Serializable;

/**
 * Represents insert/update/delete event for individual entities.
 */
final public class EntityInjestEvent extends MarshaledEvent implements Serializable {
    private EntityInjectAction action;
    private InjestedEntity injestedEntity;
    private Integer memberId;
    private String id;

    public EntityInjestEvent() {
    }

    public EntityInjestEvent(Integer memberId, EntityInjectAction action, InjestedEntity injestedEntity, String id) {
        this.action = action;
        this.injestedEntity = injestedEntity;
        this.id = id;
        this.memberId = memberId;
    }

    public EntityInjectAction getAction() {
        return action;
    }

    public void setAction(EntityInjectAction action) {
        this.action = action;
    }

    public InjestedEntity getInjestedEntity() {
        return injestedEntity;
    }

    public void setInjestedEntity(InjestedEntity injestedEntity) {
        this.injestedEntity = injestedEntity;
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
