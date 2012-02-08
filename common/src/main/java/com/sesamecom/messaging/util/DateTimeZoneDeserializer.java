package com.sesamecom.messaging.util;

import org.codehaus.jackson.JsonParser;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.DeserializationContext;
import org.codehaus.jackson.map.JsonDeserializer;
import org.joda.time.DateTimeZone;

import java.io.IOException;

public class DateTimeZoneDeserializer extends JsonDeserializer<DateTimeZone> {
    @Override
    public DateTimeZone deserialize(JsonParser jp, DeserializationContext ctxt) throws IOException, JsonProcessingException {
        return DateTimeZone.forID(jp.getText());
    }
}
