package com.sesamecom.datasource;

import org.aopalliance.intercept.MethodInterceptor;
import org.aopalliance.intercept.MethodInvocation;
import org.jooq.SchemaMapping;
import org.jooq.impl.Factory;
import org.jooq.impl.SchemaImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Provider;
import javax.inject.Singleton;
import javax.sql.DataSource;
import java.sql.Connection;

/**
 * Provides instances of Factory to use for creating queries.  Also handles drawing a connection from a DataSource when
 * entering an @ConnectionRequiring method, and closes it for you when all nested @ConnectionRequiring methods have
 * returned.
 */
@Singleton
public abstract class JooqFactoryProvider<T extends Factory> implements MethodInterceptor, Provider<T> {
    private static final Logger log = LoggerFactory.getLogger(JooqFactoryProvider.class);

    private final ThreadLocal<Connection> connectionLocal = new ThreadLocal<Connection>();
    private final ThreadLocal<Integer> referenceCount = new ThreadLocal<Integer>();

    private SchemaMapping schemaMapping;

    // no constructor injection here, because requestInjection is used to support us being a MethodInterceptor.
    protected JooqFactoryProvider() {
        schemaMapping = new SchemaMapping();
        schemaMapping.add(getSchema(), getEnvSchemaName());
    }

    protected abstract SchemaImpl getSchema();

    protected abstract String getEnvSchemaName();

    protected abstract DataSource getDataSource();

    protected abstract T newFactory(Connection connection, SchemaMapping mapping);

    @Override
    public T get() {
        Connection connection = connectionLocal.get();

        if (connection == null)
            throw new IllegalStateException("Asked for a jOOQ factory outside of an @FactoryRequiring method!");

        return newFactory(connection, schemaMapping);
    }

    @Override
    public Object invoke(MethodInvocation invocation) throws Throwable {
        if (connectionLocal.get() == null) {
            connectionLocal.set(getDataSource().getConnection());
            referenceCount.set(1);
        } else {
            referenceCount.set(referenceCount.get() + 1);
        }

        Object result;
        try {
            result = invocation.proceed();
        } finally {
            referenceCount.set(referenceCount.get() - 1);

            if (referenceCount.get() == 0) {
                connectionLocal.get().close();
                connectionLocal.remove();
                referenceCount.remove();
            }
        }

        return result;
    }
}
