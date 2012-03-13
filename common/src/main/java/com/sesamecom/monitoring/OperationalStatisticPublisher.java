package com.sesamecom.monitoring;

/**
 * Writes operational statistics to a time series back-end for later viewing.  Intended for metrics like queue sizes,
 * average job completion times, and any other variable that can be continuously sampled and recorded for monitoring
 * purposes.
 */
public interface OperationalStatisticPublisher {
    /**
     * Publish a value for a statistic.  Doing so frequently will provide high resolutions when viewing, but any given
     * statistic may only be computed once per minute.
     */
    void publish(OperationalStatistic statistic);

    /**
     * To see if the back-end is actually configured and available.  Most will gracefully fail and not prevent the
     * application from starting.
     */
    boolean backEndIsAvailable();
}
