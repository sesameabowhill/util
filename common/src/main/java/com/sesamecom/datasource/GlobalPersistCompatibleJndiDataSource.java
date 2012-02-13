package com.sesamecom.datasource;

import com.jolbox.bonecp.BoneCPDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mock.jndi.SimpleNamingContextBuilder;

import javax.inject.Provider;
import javax.naming.NamingException;
import javax.sql.DataSource;

/**
 * Establishes a JNDI DataSource at java:comp/env/jdbc/SesamePersistDB, using the connection parameter environment config
 * properties from persist (persistHost, persistPort, persistSchema, persistUser, and persistPassword).
 * <p/>
 * DataSource is connection pooled using BoneCP, which you'll need to configure via its EnvironmentConfig properties.
 * <p/>
 * This is designed as a shim for applications that use iBATIS but not persist.  (SesamePersistService also shares its
 * underlying DataSource at this JNDI location.)
 */
public class GlobalPersistCompatibleJndiDataSource {
    private static Logger log = LoggerFactory.getLogger(GlobalPersistCompatibleJndiDataSource.class);

    private static DataSource dataSource;

    public static void start() {
        log.info("Bootstrapping JNDI DataSource @ java:comp/env/jdbc/SesamePersistDB");

        try {
            Provider<DataSource> dataSourceProvider = new AbstractBoneCpDataSourceProvider(new MysqlJdbcUrlFactory()) {
                @Override
                protected String getConfigNamespace() {
                    return "persist";
                }
            };

            dataSource = dataSourceProvider.get();

            SimpleNamingContextBuilder contextBuilder = SimpleNamingContextBuilder.getCurrentContextBuilder();
            if (contextBuilder == null) {
                contextBuilder = new SimpleNamingContextBuilder();
                contextBuilder.activate();
            }

            contextBuilder.bind("java:comp/env/jdbc/SesamePersistDB", dataSource);

        } catch (NamingException e) {
            throw new RuntimeException(e);
        }
    }

    public static void stop() {
        if (dataSource instanceof BoneCPDataSource)
            ((BoneCPDataSource) dataSource).close();
    }
}
