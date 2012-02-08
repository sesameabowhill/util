package com.sesamecom.messaging;

import akka.camel.RouteDefinitionHandler;
import org.apache.camel.model.ProcessorDefinition;
import org.apache.camel.model.RouteDefinition;
import org.apache.camel.model.dataformat.JsonLibrary;

/**
 *
 */
public class CommonRouteDefinitionHandler implements RouteDefinitionHandler {
    protected Class<?> messageBodyType;

    public CommonRouteDefinitionHandler(Class<?> messageBodyType) {
        this.messageBodyType = messageBodyType;
    }

    @Override
    public ProcessorDefinition<?> onRouteDefinition(RouteDefinition route) {
        return route.unmarshal().json(JsonLibrary.Jackson, messageBodyType);
    }

    /**
     * Return route definition handler for Sns when AWS is used for message transfer.
     * @param endpointUri is used to check if AWS SQS is used
     * @param messageBodyType used to unmarshal objects
     * @return new route definition object
     */
    public static RouteDefinitionHandler getHandlerByEndpoint(String endpointUri, Class<?> messageBodyType) {
        if (endpointUri.startsWith("aws-sqs:")) {
            // if we're listening on an sqs endpoint, assume we're in production, and that the queue is being
            // written to by SNS.  in this case SNS has its own JSON envelope we must unpack the actual message
            // from.
            return new SnsRouteDefinitionHandler(messageBodyType);
        } else {
            // otherwise assume a raw JSON document with no envelope.
            return new CommonRouteDefinitionHandler(messageBodyType);
        }
    }
}
