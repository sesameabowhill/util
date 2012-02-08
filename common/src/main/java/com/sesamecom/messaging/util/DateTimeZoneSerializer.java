package com.sesamecom.messaging.util;

import org.codehaus.jackson.JsonGenerator;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.JsonSerializer;
import org.codehaus.jackson.map.SerializerProvider;
import org.joda.time.DateTimeZone;

import java.io.IOException;

public class DateTimeZoneSerializer extends JsonSerializer<DateTimeZone> {
    @Override
    public void serialize(DateTimeZone zone, JsonGenerator jgen, SerializerProvider provider) throws IOException, JsonProcessingException {
        jgen.writeString(zone.getID());
    }
}
