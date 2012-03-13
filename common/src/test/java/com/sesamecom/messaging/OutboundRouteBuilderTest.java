package com.sesamecom.messaging;

import ch.qos.logback.classic.LoggerContext;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.UnsynchronizedAppenderBase;
import com.google.inject.Guice;
import com.google.inject.Inject;
import com.google.inject.Injector;
import com.sesamecom.messaging.event.etl.Shutdown;
import org.junit.Before;
import org.junit.Test;
import org.slf4j.LoggerFactory;

import java.util.LinkedList;
import java.util.List;

import static org.hamcrest.Matchers.equalTo;
import static org.junit.Assert.assertThat;

public class OutboundRouteBuilderTest {
    @Inject
    private MessagingEventProducer producer;

    public static class MockAppender extends UnsynchronizedAppenderBase<ILoggingEvent> {
        public List<ILoggingEvent> capturedEvents = new LinkedList();

        @Override
        protected void append(ILoggingEvent iLoggingEvent) {
            capturedEvents.add(iLoggingEvent);
        }
    }

    private MockAppender appender;

    @Before
    public void setUp() {
        Injector injector = Guice.createInjector(new MessagingModule());
        injector.injectMembers(this);

        LoggerContext context = (LoggerContext) LoggerFactory.getILoggerFactory();
        appender = new MockAppender();
        appender.setContext(context);
        appender.start();
        context.getLogger("").addAppender(appender);
    }

    @Test
    public void doesntLogForDisabledEndpoint() {
        producer.sendEvent(OutboundEndpoint.Disabled, new Shutdown());
        assertThat(appender.capturedEvents.size(), equalTo(0));
    }
}
