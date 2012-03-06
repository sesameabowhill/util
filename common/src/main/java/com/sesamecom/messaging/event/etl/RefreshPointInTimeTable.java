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

    public void setUsername(String username) {
        this.username = username;
    }

    public LocalDate getRecordDate() {
        return recordDate;
    }

    public void setRecordDate(LocalDate recordDate) {
        this.recordDate = recordDate;
    }

    public String getTableName() {
        return tableName;
    }

    public void setTableName(String tableName) {
        this.tableName = tableName;
    }
}
