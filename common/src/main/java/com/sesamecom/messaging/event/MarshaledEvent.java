package com.sesamecom.messaging.event;

import org.codehaus.jackson.annotate.JsonTypeInfo;
import org.codehaus.jackson.map.annotate.JsonSerialize;

/**
 * Base class for commands that can be marshaled to and from JSON strings.
 */
@JsonSerialize
@JsonTypeInfo(use=JsonTypeInfo.Id.CLASS, include=JsonTypeInfo.As.PROPERTY, property="@command")
public abstract class MarshaledEvent {
}
