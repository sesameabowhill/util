package com.sesamecom.monitoring;

import com.google.inject.AbstractModule;

public class MonitoringModule extends AbstractModule {
    @Override
    protected void configure() {
        bind(OperationalStatisticPublisher.class).to(CloudWatchPublisher.class);
    }
}
