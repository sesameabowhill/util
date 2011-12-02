package com.sesamecom.util;

import com.jolbox.bonecp.BoneCPDataSource;
import com.sesamecom.datasource.AbstractBoneCpDataSourceProvider;
import com.sesamecom.datasource.MysqlJdbcUrlFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Provider;
import javax.naming.NamingException;
import javax.sql.DataSource;

/**
 * Establishes a JNDI DataSource at java:comp/env/jdbc/SesamePersistDB, using the connection parameter environment config
 * properties from persist (persistHost, persistPort, persistSchema, persistUser, and persistPassword).
 * <p/>
 * DataSource is connection pooled using BoneCP, which you'll need to configure via its EnvironmentConfig properties.
 */
public class GlobalPersistCompatibleJndiDataSource {
    private static Logger log = LoggerFactory.getLogger(GlobalPersistCompatibleJndiDataSource.class);

    private static DataSource dataSource;

    public static void start() {
        log.info("Bootstrapping JNDI DataSource @ java:comp/env/jdbc/SesamePersistDB");

        try {
            JndiContext jndiContext = new JndiContext();
            jndiContext.start();

            Provider<DataSource> dataSourceProvider = new AbstractBoneCpDataSourceProvider(new MysqlJdbcUrlFactory()) {
                @Override
                protected String getConfigNamespace() {
                    return "persist";
                }
            };

            dataSource = dataSourceProvider.get();

            jndiContext.bind("java:comp/env/jdbc/SesamePersistDB", dataSource);

        } catch (NamingException e) {
            throw new RuntimeException(e);
        }
    }

    public static void stop() {
        if (dataSource instanceof BoneCPDataSource)
            ((BoneCPDataSource) dataSource).close();
    }
}
