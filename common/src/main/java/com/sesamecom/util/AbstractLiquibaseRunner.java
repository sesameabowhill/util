package com.sesamecom.util;

import com.google.common.collect.ImmutableMap;
import liquibase.Liquibase;
import liquibase.database.jvm.JdbcConnection;
import liquibase.exception.LiquibaseException;
import liquibase.resource.ClassLoaderResourceAccessor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Map;

/**
 * Abstraction for classes that run Liquibase updates.
 */
public abstract class AbstractLiquibaseRunner {
    private static final Logger log = LoggerFactory.getLogger(AbstractLiquibaseRunner.class);

    protected abstract String getChangelogPath();

    protected abstract String getContext();

    protected abstract DataSource getDataSource();

    protected Map<String, Object> getParameters() {
        return ImmutableMap.of();
    }

    public void update() {
        update(getContext());
    }

    public void update(String context) {
        Connection connection;
        try {
            connection = getDataSource().getConnection();
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }

        try {
            Liquibase liquibase = new Liquibase(
                getChangelogPath(),
                new ClassLoaderResourceAccessor(),
                new JdbcConnection(connection)
            );

            for (Map.Entry<String, Object> entry : getParameters().entrySet()) {
                liquibase.setChangeLogParameter(entry.getKey(), entry.getValue());
            }

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
