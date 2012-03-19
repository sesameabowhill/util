package com.sesamecom.messaging.event.etl;

import com.sesamecom.messaging.event.MarshaledEvent;
import org.joda.time.LocalDate;

/**
 * Refresh all ranged facts for a member, where time dimension values are within the given range inclusive.
 */
public final class RefreshAllRanged extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;
    private LocalDate windowStart;
    private LocalDate windowEnd;

    @SuppressWarnings("UnusedDeclaration")
    @Deprecated // required for json serialization
    public RefreshAllRanged() {
    }

    public RefreshAllRanged(String username, LocalDate windowStart, LocalDate windowEnd) {
        this.username = username;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
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

    @Override
    public String toString() {
        return "RefreshAllRanged{" +
            "username='" + username + '\'' +
            ", windowStart=" + windowStart +
            ", windowEnd=" + windowEnd +
            '}';
    }
}
