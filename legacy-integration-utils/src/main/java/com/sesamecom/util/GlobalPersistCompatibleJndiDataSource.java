package com.sesamecom.util;

import com.jolbox.bonecp.BoneCPDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;

import static com.google.common.base.Preconditions.checkNotNull;

/**
 * Establishes a JNDI DataSource at java:comp/env/jdbc/SesameDB, using the connection parameter system properties
 * from persist (persistHost, persistPort, persistSchema, persistUser, and persistPassword).  For compatability with
 * some broken code, registers the same DataSource at java:/comp/env/jdbc/SesameDB (note the leading slash).
 *
 * DataSource is connection pooled using BoneCP, so you'll need to configure it via its system properties.  e.g.:
 *
 * -Dbonecp.idleMaxAgeInMinutes=240
 * -Dbonecp.idleConnectionTestPeriodInMinutes=60
 * -Dbonecp.connectionTestStatement="SELECT 1"
 * -Dbonecp.partitionCount=3
 * -Dbonecp.acquireIncrement=10
 * -Dbonecp.maxConnectionsPerPartition=5
 * -Dbonecp.minConnectionsPerPartition=1
 * -Dbonecp.statementsCacheSize=50
 * -Dbonecp.releaseHelperThreads=3
 *
 */
public class GlobalPersistCompatibleJndiDataSource {
    private static Logger log = LoggerFactory.getLogger(GlobalPersistCompatibleJndiDataSource.class);

    private static BoneCPDataSource dataSource;

    public static void start() {
        System.setProperty(Context.INITIAL_CONTEXT_FACTORY, "org.apache.naming.java.javaURLContextFactory");
        System.setProperty(Context.URL_PKG_PREFIXES, "org.apache.naming");

        String host = System.getProperty("persistHost");
        String port = System.getProperty("persistPort");
        String schema = System.getProperty("persistSchema");
        String user = System.getProperty("persistUser");
        String pass = System.getProperty("persistPassword");

        checkNotNull(host, "Please supply the 'persistHost' system property.");
        checkNotNull(port, "Please supply the 'persistPort' system property.");
        checkNotNull(schema, "Please supply the 'persistSchema' system property.");
        checkNotNull(user, "Please supply the 'persistUser' system property.");
        checkNotNull(pass, "Please supply the 'persistPassword' system property.");

        String url = String.format("jdbc:mysql://%s:%s/%s?characterEncoding=utf8", host, port, schema);

        log.info("Bootstrapping JNDI DataSource @ (/)comp/env/jdbc/SesameDB with {}", url);

        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException(e);
        }

        dataSource = new BoneCPDataSource();
        dataSource.setJdbcUrl(url);
        dataSource.setUsername(user);
        dataSource.setPassword(pass);
        dataSource.setConnectionTestStatement("/* ping */ SELECT 1");

        // BoneCP iterates its own properties rather than the ones you pass in, so there's no possibility of confusing
        // it by simply passing in all system properties.
        try {
            dataSource.setProperties(System.getProperties());
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        // the legacy apps weren't designed to use a pool, and so their connections must be rolled back when checked in.
        dataSource.setConnectionHook(new RollBackOnCheckInConnectionHook());

        try {
            InitialContext ic = new InitialContext();

            ic.createSubcontext("java:");
            ic.createSubcontext("java:comp");
            ic.createSubcontext("java:comp/env");
            ic.createSubcontext("java:comp/env/jdbc");
            ic.bind("java:comp/env/jdbc/SesameDB", dataSource);

            // HACK: at one point while trying to debug JNDI issues, this variant of the context path was introduced
            // into some legacy code.  cheaper to duplicate the error here (this is all legacy iBATIS code that will
            // eventually be rewritten).
            ic.createSubcontext("java:/comp");
            ic.createSubcontext("java:/comp/env");
            ic.createSubcontext("java:/comp/env/jdbc");
            ic.bind("java:/comp/env/jdbc/SesameDB", dataSource);
        } catch (NamingException e) {
            throw new RuntimeException(e);
        }
    }

    public static void stop() {
        dataSource.close();
    }
}
