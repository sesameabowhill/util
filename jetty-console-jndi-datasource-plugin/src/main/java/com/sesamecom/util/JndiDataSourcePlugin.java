package com.sesamecom.util;

import org.eclipse.jetty.webapp.WebAppContext;
import org.simplericity.jettyconsole.api.JettyConsolePluginBase;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A Jetty Console plugin that creates a JNDI data source via {@link GlobalPersistCompatibleJndiDataSource} when
 * the first WebAppContext starts, and then tears it back down when the last WebAppContext stops.
 *
 */
public class JndiDataSourcePlugin extends JettyConsolePluginBase {
    private static final Logger log = LoggerFactory.getLogger(JndiDataSourcePlugin.class);

    // count of the number of contexts we think are running.
    private int running = 0;

    public JndiDataSourcePlugin() {
        super(JndiDataSourcePlugin.class);
    }

    @Override
    public void beforeStart(WebAppContext context) {
        if (running == 0)
            GlobalPersistCompatibleJndiDataSource.start();
        running++;
    }

    @Override
    public void beforeStop(WebAppContext context) {
        running--;
        if (running <= 0)
            GlobalPersistCompatibleJndiDataSource.stop();
    }
}
