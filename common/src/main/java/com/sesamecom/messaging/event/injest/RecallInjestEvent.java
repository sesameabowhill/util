package com.sesamecom.messaging.event.injest;

/**
 *
 */
final public class RecallInjestEvent extends EntityInjestEvent {
    public RecallInjestEvent() {
    }

    public RecallInjestEvent(Integer memberId, EntityInjestAction action, String id) {
        super(memberId, action, id);
    }
}
