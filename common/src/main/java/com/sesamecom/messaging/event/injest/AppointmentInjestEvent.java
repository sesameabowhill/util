package com.sesamecom.messaging.event.injest;

/**
 *
 */
final public class AppointmentInjestEvent extends EntityInjestEvent {
    public AppointmentInjestEvent() {
    }

    public AppointmentInjestEvent(Integer memberId, EntityInjestAction action, String id) {
        super(memberId, action, id);
    }
}
