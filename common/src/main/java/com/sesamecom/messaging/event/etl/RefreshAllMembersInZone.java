package com.sesamecom.messaging.event.etl;

import com.sesamecom.messaging.event.MarshaledEvent;
import com.sesamecom.messaging.util.DateTimeZoneDeserializer;
import com.sesamecom.messaging.util.DateTimeZoneSerializer;
import org.codehaus.jackson.map.annotate.JsonDeserialize;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.joda.time.DateTimeZone;

/**
 * Refresh all members in the given time zone.
 */
public final class RefreshAllMembersInZone extends MarshaledEvent implements RefreshSupervisorCommand {
    private DateTimeZone timeZone;

    public RefreshAllMembersInZone() {
    }

    public RefreshAllMembersInZone(DateTimeZone timeZone) {
        this.timeZone = timeZone;
    }

    @JsonSerialize(using=DateTimeZoneSerializer.class)
    public DateTimeZone getTimeZone() {
        return timeZone;
    }

    @JsonDeserialize(using=DateTimeZoneDeserializer.class)
    public void setTimeZone(DateTimeZone timeZone) {
        this.timeZone = timeZone;
    }

    @Override
    public String toString() {
        return "RefreshAllMembersInZone{" +
            "timeZone=" + timeZone +
            '}';
    }
}
