package com.sesamecom.messaging;

import com.sesamecom.messaging.util.SnsEnvelopeDataFormat;
import org.apache.camel.model.ProcessorDefinition;
import org.apache.camel.model.RouteDefinition;

/**
 *
 */
public class SnsRouteDefinitionHandler extends CommonRouteDefinitionHandler {
    public SnsRouteDefinitionHandler(Class<?> messageBodyType) {
        super(messageBodyType);
    }

    @Override
    public ProcessorDefinition<?> onRouteDefinition(RouteDefinition route) {
        return route.unmarshal(new SnsEnvelopeDataFormat(messageBodyType));
    }
}
