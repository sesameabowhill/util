package com.sesamecom.messaging.event;

import org.joda.time.LocalDate;

/**
 * Refresh all point-in-time facts for a member, using the supplied LocalDate as the time dimension value, which should
 * always be a representation of "yesterday" in their local time zone unless testing.
 */
public class RefreshMemberPointInTime extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;
    private LocalDate recordDate;

    public RefreshMemberPointInTime() {
    }

    public RefreshMemberPointInTime(String username, LocalDate recordDate) {
        this.username = username;
        this.recordDate = recordDate;
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

    @Override
    public String toString() {
        return "RefreshMemberPointInTime{" +
            "username='" + username + '\'' +
            ", timeDimensionMember=" + recordDate +
            '}';
    }
}
