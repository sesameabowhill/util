package com.sesamecom.messaging.event.ingest;

import com.sesamecom.messaging.event.AbstractMemberEvent;

/**
 * Fired when an initial is ingested on top of a previous initial.
 */
public class ReinitialUploadIngestCompleted extends AbstractMemberEvent {
    private int previousInitialDatasetVersionId;
    private int newInitialDatasetVersionId;

    @SuppressWarnings({"UnusedDeclaration", "deprecation"})
    @Deprecated // required for json (de)serialization
    public ReinitialUploadIngestCompleted() {
    }

    public ReinitialUploadIngestCompleted(Integer memberId, int previousInitialDatasetVersionId, int newInitialDatasetVersionId) {
        super(memberId);
        this.previousInitialDatasetVersionId = previousInitialDatasetVersionId;
        this.newInitialDatasetVersionId = newInitialDatasetVersionId;
    }

    public int getPreviousInitialDatasetVersionId() {
        return previousInitialDatasetVersionId;
    }

    public void setPreviousInitialDatasetVersionId(int previousInitialDatasetVersionId) {
        this.previousInitialDatasetVersionId = previousInitialDatasetVersionId;
    }

    public int getNewInitialDatasetVersionId() {
        return newInitialDatasetVersionId;
    }

    public void setNewInitialDatasetVersionId(int newInitialDatasetVersionId) {
        this.newInitialDatasetVersionId = newInitialDatasetVersionId;
    }
}
