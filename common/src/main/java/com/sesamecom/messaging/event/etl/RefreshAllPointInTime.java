package com.sesamecom.messaging.event.etl;

import com.sesamecom.messaging.event.MarshaledEvent;
import org.joda.time.LocalDate;

/**
 * Refresh all point-in-time facts for a member, using the supplied LocalDate as the time dimension value, which should
 * always be a representation of "yesterday" in their local time zone.
 */
public class RefreshAllPointInTime extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;
    private LocalDate recordDate;

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public RefreshAllPointInTime() {
    }

    public RefreshAllPointInTime(String username, LocalDate recordDate) {
        this.username = username;
        this.recordDate = recordDate;
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

    @Override
    public String toString() {
        return "RefreshAllPointInTime{" +
            "username='" + username + '\'' +
            ", timeDimensionMember=" + recordDate +
            '}';
    }
}
