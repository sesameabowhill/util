package com.sesamecom.messaging.util;

import org.apache.camel.Exchange;
import org.apache.camel.spi.DataFormat;
import org.codehaus.jackson.map.ObjectMapper;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.Map;

/**
 * Similar to JacksonDataType, but only supports unmarshaling.  Operates on SNS envelopes, unpacking a nested JSON
 * message and mapping it as the type specified.
 */
public class SnsEnvelopeDataFormat implements DataFormat {
    private static final ObjectMapper objectMapper = new ObjectMapper();
    private Class<?> messageBodyType;

    public SnsEnvelopeDataFormat(Class<?> messageBodyType) {
        this.messageBodyType = messageBodyType;
    }

    /**
     * Should never be used, as SNS writes this DataFormat, not us.
     */
    @Override
    public void marshal(Exchange exchange, Object graph, OutputStream stream) throws Exception {
        throw new UnsupportedOperationException("SNS writes this DataFormat, we only unmarshal it.");
    }

    @Override
    public Object unmarshal(Exchange exchange, InputStream stream) throws Exception {
        Map envelope = objectMapper.readValue(stream, Map.class);
        return objectMapper.readValue((String) envelope.get("Message"), messageBodyType);
    }


}
