package com.sesamecom.datasource;

import javax.sql.DataSource;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * A trivial DataSource that just calls the driver manager each time.
 */
public abstract class AbstractBasicDataSourceProvider extends AbstractDataSourceProvider implements DataSource {
    private PrintWriter logWriter;
    private Integer loginTimeout;
    private JdbcUrlFactory urlFactory;

    protected AbstractBasicDataSourceProvider(JdbcUrlFactory urlFactory) {
        this.urlFactory = urlFactory;
    }

    @Override
    public DataSource get() {
        try {
            Class.forName("com.mysql.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException(e);
        }

        return this;
    }

    @Override
    public Connection getConnection() throws SQLException {
        return DriverManager.getConnection(urlFactory.makeUrl(host, port, schema), user, password);
    }

    @Override
    public Connection getConnection(String username, String password) throws SQLException {
        return getConnection();
    }

    @Override
    public PrintWriter getLogWriter() throws SQLException {
        return logWriter;
    }

    @Override
    public void setLogWriter(PrintWriter out) throws SQLException {
        logWriter = out;
    }

    @Override
    public void setLoginTimeout(int seconds) throws SQLException {
        loginTimeout = seconds;
    }

    @Override
    public int getLoginTimeout() throws SQLException {
        return loginTimeout;
    }

    @Override
    public <T> T unwrap(Class<T> iface) throws SQLException {
        // if you say so...
        return (T) this;
    }

    @Override
    public boolean isWrapperFor(Class<?> iface) throws SQLException {
        return false;
    }
}