package com.sesamecom.messaging.event.etl;

import com.sesamecom.messaging.event.MarshaledEvent;
import org.joda.time.LocalDate;

/**
 * Refreshes a member's facts in a specific point-in-time table for the given recordDate.
 */
public class RefreshPointInTimeTable extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;
    private LocalDate recordDate;
    private String tableName;

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public RefreshPointInTimeTable() {
    }

    public RefreshPointInTimeTable(String username, LocalDate recordDate, String tableName) {
        this.username = username;
        this.recordDate = recordDate;
        this.tableName = tableName;
    }

    public String getUsername() {
        return username;
    }

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public void setUsername(String username) {
        this.username = username;
    }

    public LocalDate getRecordDate() {
        return recordDate;
    }

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public void setRecordDate(LocalDate recordDate) {
        this.recordDate = recordDate;
    }

    public String getTableName() {
        return tableName;
    }

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public void setTableName(String tableName) {
        this.tableName = tableName;
    }

    @Override
    public String toString() {
        return "RefreshPointInTimeTable{" +
            "username='" + username + '\'' +
            ", recordDate=" + recordDate +
            ", tableName='" + tableName + '\'' +
            '}';
    }
}
