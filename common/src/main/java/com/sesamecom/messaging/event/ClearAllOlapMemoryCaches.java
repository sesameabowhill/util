package com.sesamecom.messaging.event;

import java.io.Serializable;

/**
 * Indicates to remote OLAP services that they should clear their caches as new data is available.
 */
public final class ClearAllOlapMemoryCaches extends MarshaledEvent implements Serializable {
}
