package com.sesamecom.messaging.event.etl;

import com.sesamecom.messaging.event.MarshaledEvent;

import java.io.Serializable;

/**
 * Gracefully shut down the ETL service, allowing it to complete all in-process commands.  Queued commands will be
 * discarded.
 */
public final class Shutdown extends MarshaledEvent implements Serializable {
}
