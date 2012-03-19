package com.sesamecom.messaging.event.etl;

import com.sesamecom.messaging.event.MarshaledEvent;
import org.joda.time.LocalDate;

/**
 * Refresh a member's facts in a single ranged fact table for a given range.
 */
public class RefreshRangedTable extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;
    private LocalDate windowStart;
    private LocalDate windowEnd;
    private String tableName;

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public RefreshRangedTable() {
    }

    public RefreshRangedTable(String username, LocalDate windowStart, LocalDate windowEnd, String tableName) {
        this.username = username;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
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

    public LocalDate getWindowStart() {
        return windowStart;
    }

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public void setWindowStart(LocalDate windowStart) {
        this.windowStart = windowStart;
    }

    public LocalDate getWindowEnd() {
        return windowEnd;
    }

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public void setWindowEnd(LocalDate windowEnd) {
        this.windowEnd = windowEnd;
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
        return "RefreshRangedTable{" +
            "username='" + username + '\'' +
            ", windowStart=" + windowStart +
            ", windowEnd=" + windowEnd +
            ", tableName='" + tableName + '\'' +
            '}';
    }
}
