package com.sesamecom.datasource;

import javax.inject.Singleton;

import static org.apache.commons.lang.StringUtils.join;

@Singleton
public class MysqlJdbcUrlFactory implements JdbcUrlFactory {
    @Override
    public String makeUrl(String host, Integer port, String schema) {
        String[] parameters = new String[] {
            // without zeroDateTimeBehavior=convertToNull, mysql jdbc driver throws exceptions over empty timestamps
            // and dates, which are found in legacy tables such as client_settings
            "zeroDateTimeBehavior=convertToNull",

            // character encoding!
            "characterEncoding=utf8",

            // used to collapse batched statements into a single "line" for higher throughput
            "rewriteBatchedStatements=true",

            // TODO: anyone remember what this one is for?
            "jdbcCompliantTruncation=false"
        };

        return String.format("jdbc:mysql://%s:%s/%s?%s", host, port, schema, join(parameters, "&"));
    }

}
