package com.sesamecom.messaging.event.ingest;

/**
 *
 */
final public class AppointmentIngestEvent extends EntityIngestEvent {
    @SuppressWarnings({"UnusedDeclaration", "deprecation"})
    @Deprecated // required for json serialization
    public AppointmentIngestEvent() {
    }

    public AppointmentIngestEvent(Integer memberId, EntityIngestAction action, String id) {
        super(memberId, action, id);
    }
}
