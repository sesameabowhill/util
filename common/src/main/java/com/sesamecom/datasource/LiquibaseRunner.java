package com.sesamecom.datasource;

import liquibase.Liquibase;
import liquibase.database.jvm.JdbcConnection;
import liquibase.exception.LiquibaseException;
import liquibase.resource.ClassLoaderResourceAccessor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Singleton;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

/**
 * Convenience class for running Liquibase updates.
 */
@Singleton
public class LiquibaseRunner {
    private static final Logger log = LoggerFactory.getLogger(LiquibaseRunner.class);

    public void update(String changelogPath, String context, DataSource dataSource) {
        Connection connection = null;
        try {
            connection = dataSource.getConnection();
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }

        try {
            Liquibase liquibase = new Liquibase(
                changelogPath,
                new ClassLoaderResourceAccessor(),
                new JdbcConnection(connection)
            );
            liquibase.update(context);

        } catch (LiquibaseException e) {
            throw new RuntimeException(e);

        } finally {
            try {
                connection.close();
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }
        }
    }
}
