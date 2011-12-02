package com.sesamecom.datasource;

import com.jolbox.bonecp.BoneCPDataSource;
import com.sesamecom.config.EnvironmentConfig;

import javax.sql.DataSource;

/**
 * Connection pooling can be configure via these optional EnvironmentConfig properties (recommended):
 *
 * bonecp.idleMaxAgeInMinutes=240
 * bonecp.idleConnectionTestPeriodInMinutes=60
 * bonecp.partitionCount=3
 * bonecp.acquireIncrement=10
 * bonecp.maxConnectionsPerPartition=5
 * bonecp.minConnectionsPerPartition=1
 * bonecp.statementsCacheSize=50
 * bonecp.releaseHelperThreads=3
 */
public abstract class AbstractBoneCpDataSourceProvider extends AbstractDataSourceProvider {
    private JdbcUrlFactory urlFactory;

    protected AbstractBoneCpDataSourceProvider(JdbcUrlFactory urlFactory) {
        this.urlFactory = urlFactory;
    }

    @Override
    public DataSource get() {
        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException(e);
        }

        BoneCPDataSource dataSource = new BoneCPDataSource();
        dataSource.setJdbcUrl(urlFactory.makeUrl(host, port, schema));
        dataSource.setConnectionTestStatement("/* ping */ SELECT 1");
        dataSource.setUsername(user);
        dataSource.setPassword(password);
        dataSource.setDefaultAutoCommit(true);

        // BoneCP iterates its own properties rather than the ones you pass in, so there's no possibility of confusing
        // it by simply passing in all config properties and letting it pick through.
        try {
            dataSource.setProperties(EnvironmentConfig.getProperties());
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        // this is a stop-gap to prevent in-transaction connections from ending up back in the connection pool.  there
        // is some small cost for MySQL to process the redundant commands, but it's way better than locks being held
        // accidentally!
        dataSource.setConnectionHook(new RollBackOnCheckInConnectionHook());

        return dataSource;
    }    
}
