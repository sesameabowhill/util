package com.sesamecom.messaging.event;

import org.joda.time.LocalDate;

/**
 * Refresh all facts for a member whose time dimension members are within the given range, inclusive.
 */
public final class RefreshMemberRanged extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;
    private LocalDate windowStart;
    private LocalDate windowEnd;

    public RefreshMemberRanged() {
    }

    public RefreshMemberRanged(String username, LocalDate windowStart, LocalDate windowEnd) {
        this.username = username;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public LocalDate getWindowStart() {
        return windowStart;
    }

    public void setWindowStart(LocalDate windowStart) {
        this.windowStart = windowStart;
    }

    public LocalDate getWindowEnd() {
        return windowEnd;
    }

    public void setWindowEnd(LocalDate windowEnd) {
        this.windowEnd = windowEnd;
    }

    @Override
    public String toString() {
        return "RefreshMemberRanged{" +
            "username='" + username + '\'' +
            ", windowStart=" + windowStart +
            ", windowEnd=" + windowEnd +
            '}';
    }
}
