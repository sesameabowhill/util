package com.sesamecom.util;

import com.jolbox.bonecp.BoneCPDataSource;
import org.eclipse.jetty.webapp.WebAppContext;
import org.simplericity.jettyconsole.api.DefaultStartOption;
import org.simplericity.jettyconsole.api.JettyConsolePluginBase;
import org.simplericity.jettyconsole.api.StartOption;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;

import static java.lang.Integer.parseInt;
import static java.lang.Long.parseLong;

/**
 * A Jetty Console plugin that creates a JNDI data source using persist and bonecp system properties.
 */
public class JndiDataSourcePlugin extends JettyConsolePluginBase {
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

        String host = System.getProperty("persistHost", "localhost");
        String port = System.getProperty("persistPort", "3306");
        String schema = System.getProperty("persistSchema", "sesame_db");
        String user = System.getProperty("persistUser", "sesame");
        String pass = System.getProperty("persistPassword", "");

        String url = String.format("jdbc:mysql://%s:%s/%s?characterEncoding=utf8", host, port, schema);

        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException(e);
        }

        dataSource = new BoneCPDataSource();
        dataSource.setJdbcUrl(url);
        dataSource.setUsername(user);
        dataSource.setPassword(pass);

        String idleMaxAgeInMinutes = System.getProperty("bonecp.idleMaxAgeInMinutes", "240");
        String idleConnectionTestPeriodInMinutes = System.getProperty("bonecp.idleConnectionTestPeriodInMinutes", "60");
        String connectionTestStatement = System.getProperty("bonecp.connectionTestStatement", "/* ping */ SELECT 1");
        String partitionCount = System.getProperty("bonecp.partitionCount", "3");
        String acquireIncrement = System.getProperty("bonecp.acquireIncrement", "10");
        String maxConnectionsPerPartition = System.getProperty("bonecp.maxConnectionsPerPartition", "50");
        String minConnectionsPerPartition = System.getProperty("bonecp.minConnectionsPerPartition", "10");
        String statementsCacheSize = System.getProperty("bonecp.statementsCacheSize", "50");
        String releaseHelperThreads = System.getProperty("bonecp.releaseHelperThreads", "3");

        dataSource.setIdleMaxAgeInMinutes(parseLong(idleMaxAgeInMinutes));
        dataSource.setIdleConnectionTestPeriodInMinutes(parseLong(idleConnectionTestPeriodInMinutes));
        dataSource.setConnectionTestStatement(connectionTestStatement);
        dataSource.setPartitionCount(parseInt(partitionCount));
        dataSource.setAcquireIncrement(parseInt(acquireIncrement));
        dataSource.setMaxConnectionsPerPartition(parseInt(maxConnectionsPerPartition));
        dataSource.setMinConnectionsPerPartition(parseInt(minConnectionsPerPartition));
        dataSource.setStatementsCacheSize(parseInt(statementsCacheSize));
        dataSource.setReleaseHelperThreads(parseInt(releaseHelperThreads));

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
