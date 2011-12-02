package com.sesamecom.datasource;

import javax.inject.Provider;
import javax.sql.DataSource;

import static com.sesamecom.config.EnvironmentConfig.getProperty;

/**
 * Abstraction for DataSource providers.  Simply override a subclass with the namespace for your configuration in
 * EnvironmentConfig, e.g. "persist" to read properties from persistSchema, persistHost, etc.
 * <p/>
 * The following EnvironmentConfig properties are required for basic connection settings:
 * <p/>
 * [namespace]Host=localhost [namespace]Port=3306 [namespace]User=yourmysqluser [namespace]Password=yourmysqlpassword
 * [namespace]Schema=yourschemaname
 */
public abstract class AbstractDataSourceProvider implements Provider<DataSource> {
    protected String host;
    protected Integer port;
    protected String schema;
    protected String user;
    protected String password;

    protected abstract String getConfigNamespace();

    protected AbstractDataSourceProvider() {
        String namespace = getConfigNamespace();

        host = getProperty(namespace + "Host", String.class);
        port = getProperty(namespace + "Port", Integer.class);
        schema = getProperty(namespace + "Schema", String.class);
        user = getProperty(namespace + "User", String.class);
        password = getProperty(namespace + "Password", String.class);
    }
}
