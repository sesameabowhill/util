package com.sesamecom.datasource;

/**
 * Contract for making JDBC URLs.
 */
public interface JdbcUrlFactory {
    String makeUrl(String host, Integer port, String schema);
}
