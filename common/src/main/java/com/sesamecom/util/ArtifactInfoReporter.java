package com.sesamecom.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletContext;
import java.io.IOException;
import java.io.InputStream;
import java.util.jar.Attributes;
import java.util.jar.Manifest;

/**
 * Inspects a Manifest object to determine if it was produced on the build server, and logs information about the
 * artifact if so.
 */
public class ArtifactInfoReporter {
    private static final Logger log = LoggerFactory.getLogger(ArtifactInfoReporter.class);

    private static void logBuildServerInfoIfPresent(InputStream manifestInputStream) {
        Manifest manifest;
        try {
            manifest = new Manifest(manifestInputStream);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        Attributes attributes = manifest.getMainAttributes();
        
        if (attributes.getValue("JenkinsBuildTag") != null && ! "null".equals(attributes.getValue("JenkinsBuildTag")))
            log.info("artifact->buildInformation buildTag: {}, buildId: {}, buildUrl: {}, gitBranch: {}, gitCommit: {}",
                new Object[]{
                    attributes.getValue("JenkinsBuildTag"),
                    attributes.getValue("JenkinsBuildId"),
                    attributes.getValue("JenkinsBuildUrl"),
                    attributes.getValue("GitBranch"),
                    attributes.getValue("GitCommit")
                }
            );
    }

    public static void logBuildServerInfoIfPresent(ServletContext servletContext) {
        InputStream inputStream = servletContext.getResourceAsStream("/META-INF/MANIFEST.MF");
        logBuildServerInfoIfPresent(inputStream);
    }
}
