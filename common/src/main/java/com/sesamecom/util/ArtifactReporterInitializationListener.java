package com.sesamecom.util;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

public class ArtifactReporterInitializationListener implements ServletContextListener {
    @Override
    public void contextInitialized(ServletContextEvent servletContextEvent) {
        ArtifactInfoReporter.logBuildServerInfoIfPresent(servletContextEvent.getServletContext());
    }

    @Override
    public void contextDestroyed(ServletContextEvent servletContextEvent) {
    }
}
