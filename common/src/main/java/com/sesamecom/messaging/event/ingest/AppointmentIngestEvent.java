package com.sesamecom.messaging.event.ingest;

/**
 *
 */
final public class AppointmentIngestEvent extends EntityIngestEvent {
    public AppointmentIngestEvent() {
    }

    public AppointmentIngestEvent(Integer memberId, EntityIngestAction action, String id) {
        super(memberId, action, id);
    }
}
