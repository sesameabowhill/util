package com.sesamecom.messaging.event.ingest;

import com.sesamecom.messaging.event.AbstractMemberEvent;

/**
 * Indicates that initial upload occured, so all dependant events must be cleared out.
 * There is no efficient way to tell was exactly was changed during initial upload.
 */
final public class InitialUploadIngestCompleted extends AbstractMemberEvent {
    @SuppressWarnings({"UnusedDeclaration", "deprecation"})
    @Deprecated // required for json serialization
    public InitialUploadIngestCompleted() {
    }

    public InitialUploadIngestCompleted(Integer memberId) {
        super(memberId);
    }
}
