package com.sesamecom.util;

import com.jolbox.bonecp.BoneCPDataSource;
import org.eclipse.jetty.webapp.WebAppContext;
import org.simplericity.jettyconsole.api.DefaultStartOption;
import org.simplericity.jettyconsole.api.JettyConsolePluginBase;
import org.simplericity.jettyconsole.api.StartOption;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;

import static com.google.common.base.Preconditions.checkNotNull;

/**
 * A Jetty Console plugin that creates a JNDI data source using persist and bonecp system properties.
 */
public class JndiDataSourcePlugin extends JettyConsolePluginBase {
    private static final Logger log = LoggerFactory.getLogger(JndiDataSourcePlugin.class);

    private BoneCPDataSource dataSource;

    private StartOption startOption = new DefaultStartOption(
        "jndiDataSource",
        "Use Persist and BoneCP system properties to configure a JNDI DataSource at /comp/env/jdbc/SesameDB.",
        "Options"
    );

    public JndiDataSourcePlugin() {
        super(JndiDataSourcePlugin.class);
        addStartOptions(startOption);
    }

    @Override
    public void beforeStart(WebAppContext context) {
        System.setProperty(Context.INITIAL_CONTEXT_FACTORY, "org.apache.naming.java.javaURLContextFactory");
        System.setProperty(Context.URL_PKG_PREFIXES, "org.apache.naming");

        // CODE DEBT: copied from SesamePersistModule
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

        if (System.getProperty("hibernate.connection.provider_class") == null) {
            log.warn("No connection pool provider configured via hibernate.connection.provider_class!");
            log.warn("If this is a deployed application, it will eventually error out due to stale connections!");
        }
        
        String url = String.format("jdbc:mysql://%s:%s/%s?characterEncoding=utf8", host, port, schema);

        log.info("Bootstrapping JNDI DataSource @ /comp/env/jdbc/SesameDB with {}", url);

        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException(e);
        }

        dataSource = new BoneCPDataSource();
        dataSource.setJdbcUrl(url);
        dataSource.setUsername(user);
        dataSource.setPassword(pass);

        try {
            InitialContext ic = new InitialContext();

            ic.createSubcontext("java:");
            ic.createSubcontext("java:/comp");
            ic.createSubcontext("java:/comp/env");
            ic.createSubcontext("java:/comp/env/jdbc");

            ic.bind("java:/comp/env/jdbc/SesameDB", dataSource);
        } catch (NamingException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void beforeStop(WebAppContext context) {
        dataSource.close();
    }
}
