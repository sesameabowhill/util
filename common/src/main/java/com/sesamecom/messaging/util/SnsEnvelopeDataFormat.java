package com.sesamecom.messaging.util;

import com.google.common.io.CharStreams;
import org.apache.camel.Exchange;
import org.apache.camel.spi.DataFormat;
import org.codehaus.jackson.map.ObjectMapper;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.Map;

/**
 * Similar to JacksonDataType, but only supports unmarshaling.  Operates on JSON messages potentially wrapped in an SNS
 * envelope, unpacking a nested JSON message and mapping it as the type specified where needed.
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
        String message = CharStreams.toString(new InputStreamReader(stream));
        Map map = objectMapper.readValue(message, Map.class);

        // looks like an SNS envelope to me!
        if (map.containsKey("Type") && map.containsKey("MessageId") && map.containsKey("TopicArn") && map.containsKey("Message"))
            message = map.get("Message").toString();

        return objectMapper.readValue(message, messageBodyType);
    }
}
