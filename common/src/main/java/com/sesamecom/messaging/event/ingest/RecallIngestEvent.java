package com.sesamecom.messaging.event.ingest;

/**
 *
 */
final public class RecallIngestEvent extends EntityIngestEvent {
    @SuppressWarnings({"UnusedDeclaration", "deprecation"})
    @Deprecated // required for json serialization
    public RecallIngestEvent() {
    }

    public RecallIngestEvent(Integer memberId, EntityIngestAction action, String id) {
        super(memberId, action, id);
    }
}
