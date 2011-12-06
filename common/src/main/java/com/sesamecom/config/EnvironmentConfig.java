package com.sesamecom.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.swing.text.html.Option;
import java.io.File;
import java.io.FileInputStream;
import java.util.*;

import static com.sesamecom.config.ConfigRequirementType.OPTIONAL;
import static com.sesamecom.config.ConfigRequirementType.REQUIRED;

/**
 * Globally defines and provides read-only access to per-environment configuration properties on sesame components.
 * <p/>
 * Properties are optionally read at class initialization from a properties file at the path defined by the system
 * property sesameConfigurationFile.  The same properties can be defined directly using system properties, which will
 * override values in the file.  Changes to the properties file are only picked up on JVM restart.
 * <p/>
 * A separate getter method for each property is defined in this class to allow for appropriate type conversions, and to
 * provide a convenient way to throw an exception when you require a property that isn't defined.  The names of the
 * properties read by the getter methods are included in their Javadoc comment.  When a required property is missing,
 * ConfigPropertyMissingException is thrown.  When a property's value cannot be parsed, BadConfigPropertyValueException
 * is thrown.
 * <p/>
 * Each getter method has an overload that accepts a default value to return for when the property is optional.  i.e.
 * These defaults are not defined in this class, but by the caller.
 */
public class EnvironmentConfig {
    private static final Logger log = LoggerFactory.getLogger(EnvironmentConfig.class);

    private static final String CONFIG_FILE_PATH_SYSTEM_PROPERTY = "sesameConfigurationFile";
    private static final String configFilePath = System.getProperty(CONFIG_FILE_PATH_SYSTEM_PROPERTY);

    private static enum Source {SYSTEM, FILE}

    private static final Map<String, Source> propertySource = new HashMap();
    private static final Properties properties = resolveProperties();

    /**
     * Used to let the application know it is in dev mode.  Provides dev features like auto-login.
     * <p/>
     * Property: mdDevMode
     */
    public static Boolean getDevMode(Boolean defaultValue) {
        return getProperty("mdDevMode", Boolean.class, OPTIONAL, defaultValue);
    }

    /**
     * Used to let the application know it is in dem mode.  Uses local data for website analytics.
     * <p/>
     * Property: mdDemoMode
     */
    public static Boolean getDemoMode(Boolean defaultValue) {
        return getProperty("mdDemoMode", Boolean.class, OPTIONAL, defaultValue);
    }

    /**
     * Used to let the application know it is in production mode.  JIRA tickets created by MD will be created in
     * their correct projects, not Test Project (TP).
     * <p/>
     * Property: mdProdMode
     */
    public static Boolean getProductionMode(Boolean defaultValue) {
        return getProperty("mdProdMode", Boolean.class, OPTIONAL, defaultValue);
    }

    /**
     * Returns the theme to use for MD.
     * <p/>
     * Property: dashboardTheme
     */
    public static String getDashboardTheme(String defaultTheme) {
        return getProperty("dashboardTheme", String.class, OPTIONAL, defaultTheme);
    }
    
    /**
     * Used to prevent Liquibase from running when SesamePersistService starts up.
     * <p/>
     * Property: skipLiquibaseUpdate
     */
    public static Boolean getSkipLiquibaseUpdate(Boolean defaultValue) {
        return getProperty("skipLiquibaseUpdate", Boolean.class, OPTIONAL, defaultValue);
    }

    /**
     * Causes persist and analytics to use a basic, non-pooling JDBC DataSource.  <b></b>This should only be used for
     * testing and development!</b>
     */
    public static Boolean getUseBasicDataSource(Boolean defaultValue) {
        return getProperty("useBasicDataSource", Boolean.class, OPTIONAL, defaultValue);
    }

    /**
     * The hostname of the MySQL instance to connect to for access to the persist database.
     * <p/>
     * Property: persistHost
     */
    public static String getPersistHost() {
        return getProperty("persistHost", String.class);
    }

    /**
     * The port of the MySQL instance to connect to for access to the persist database.
     * <p/>
     * Property: persistPort
     */
    public static Integer getPersistPort(Integer defaultValue) {
        return getProperty("persistPort", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getPersistPort() {
        return getProperty("persistPort", Integer.class);
    }

    /**
     * The schema on the MySQL instance to use for access to the persist database.
     * <p/>
     * Property: persistSchema
     */
    public static String getPersistSchema() {
        return getProperty("persistSchema", String.class);
    }

    /**
     * The username to use when connecting to the persist database.
     * <p/>
     * Property: persistUser
     */
    public static String getPersistUser() {
        return getProperty("persistUser", String.class);
    }

    /**
     * The password to use when connecting to the persist database.
     * <p/>
     * Property: persistPassword
     */
    public static String getPersistPassword() {
        return getProperty("persistPassword", String.class);
    }

    /**
     * The hostname of the MySQL instance to connect to for access to the analytics database.
     * <p/>
     * Property: analyticsHost
     */
    public static String getAnalyticsHost() {
        return getProperty("analyticsHost", String.class);
    }

    /**
     * The port of the MySQL instance to connect to for access to the analytics database.
     * <p/>
     * Property: analyticsPort
     */
    public static Integer getAnalyticsPort(Integer defaultValue) {
        return getProperty("analyticsPort", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getAnalyticsPort() {
        return getProperty("analyticsPort", Integer.class);
    }

    /**
     * The schema on the MySQL instance to use for access to the analytics database.
     * <p/>
     * Property: analyticsSchema
     */
    public static String getAnalyticsSchema() {
        return getProperty("analyticsSchema", String.class);
    }

    /**
     * The username to use when connecting to the analytics database.
     * <p/>
     * Property: analyticsUser
     */
    public static String getAnalyticsUser() {
        return getProperty("analyticsUser", String.class);
    }

    /**
     * The password to use when connecting to the analytics database.
     * <p/>
     * Property: analyticsPassword
     */
    public static String getAnalyticsPassword() {
        return getProperty("analyticsPassword", String.class);
    }

    /**
     * Whether or not analytics ETLs should use MySQL's INSERT INTO .. SELECT FROM .. instead of buffering the results
     * of select statements and issuing individual inserts.
     * <p/>
     * <b>Note that if this is enabled, the MySQL server at analyticsHost must have innodb_locks_unsafe_for_binlog
     * enabled, or ETLs will encounter locking problems!</b>
     */
    public static Boolean getAnalyticsEtlUseInsertIntoSelectFrom(Boolean defaultValue) {
        return (Boolean) getProperty("analyticsEtlUseInsertIntoSelectFrom", Boolean.class, OPTIONAL, defaultValue);
    }

    /**
     * How many records to put in each batched insert in the analytics ETLs.  Only effects fact table loading when
     * analyticsEtlUseInsertIntoSelectFrom is false, but always effects dimension table loading.
     * <p/>
     * Property: analyticsEtlBatchSize
     */
    public static Integer getAnalyticsEtlBatchSize(Integer defaultValue) {
        return getProperty("analyticsEtlBatchSize", Integer.class, OPTIONAL, defaultValue);
    }

    /**
     * How many records to insert during one transaction in the analytics ETLs.  Only effects fact table loading when
     * analyticsEtlUseInsertIntoSelectFrom is false, but always effects dimension table loading.
     * <p/>
     * Property: analyticsEtlTransactionSize
     */
    public static Integer getAnalyticsEtlTransactionSize(Integer defaultValue) {
        return getProperty("analyticsEtlTransactionSize", Integer.class, OPTIONAL, defaultValue);
    }

    /**
     * Concurrency level to use for ETLs.  Corresponds to number of simultaneous database connections and queries.
     * <p/>
     * Property: analyticsEtlConcurrencyCount
     */
    public static Integer getAnalyticsEtlConcurrencyCount(Integer defaultValue) {
        return getProperty("analyticsEtlConcurrencyCount", Integer.class, OPTIONAL, defaultValue);
    }

    /**
     * How many days worth of data to refresh when doing ranged refreshes.
     * <p/>
     * Property: analyticsEtlRefreshDayRange
     */
    public static Integer getAnalyticsEtlRefreshDayRange(Integer defaultValue) {
        return getProperty("analyticsEtlRefreshDayRange", Integer.class, OPTIONAL, defaultValue);
    }

    /**
     * The Camel endpoint the ETL service listens for ad-hoc commands on.
     * <p/>
     * Property: analyticsEtlAdHocCommandEndpoint
     */
    public static String getAnalyticsEtlAdHocCommandEndpoint() {
        return getProperty("analyticsEtlAdHocCommandEndpoint", String.class);
    }

    /**
     * The Camel endpoint the OLAP service listens for ad-hoc commands on.
     * <p/>
     * Property: analyticsOlapAdHocCommandEndpoint
     */
    public static String getAnalyticsOlapAdHocCommandEndpoint(String defaultValue) {
        return getProperty("analyticsOlapAdHocCommandEndpoint", String.class, OPTIONAL, defaultValue);
    }

    public static String getAnalyticsOlapAdHocCommandEndpoint() {
        return getProperty("analyticsOlapAdHocCommandEndpoint", String.class);
    }

    /**
     * The environment definition for "SESAME_COMMON".
     * <p/>
     * Property: sesameCommon
     */
    public static String getSesameCommon() {
        return getProperty("sesameCommon", String.class);
    }

    /**
     * The Liquibase context to run under when migration is performed for the persist database.
     * <p/>
     * Property: persistLiquibaseContext
     */
    public static String getPersistLiquibaseContext(String defaultValue) {
        return getProperty("persistLiquibaseContext", String.class, OPTIONAL, defaultValue);
    }

    /**
     * Provides raw, read-only access to all properties defined.  This can be useful when some properties are used to
     * configure a third party component that knows how to get them from a Properties object.
     */
    public static Properties getProperties() {
        return new Properties(properties);
    }

    /**
     * <b>Please avoid using this method!</p>
     * <p/>
     * Instead create a getter for your property, so it can be documented and its use easily traced.  This is only made
     * public to support a few special cases.
     */
    public static <T> T getProperty(String propertyName, Class<T> targetType) {
        return getProperty(propertyName, targetType, REQUIRED, null);
    }

    /**
     * Gets and parses a property given name, type, and requirementType.  Throws ConfigPropertyMissingException if a
     * requirement type is REQUIRED and no value is defined, BadConfigPropertyValueException if a value is defined but
     * cannot be parsed, and RuntimeException if the type specified is not supported.
     */
    private static <T> T getProperty(String propertyName, Class<T> targetType, ConfigRequirementType requirementType, T defaultValue) {
        String stringValue = (String) properties.get(propertyName);

        // bail out if we can't find it and it's required, return defaultValue if only the former.
        if (stringValue == null) {
            if (ConfigRequirementType.REQUIRED.equals(requirementType)) {
                log.error(
                    "requiredProperty->missing property: {}, configFilePath: {}",
                    propertyName,
                    getConfigPathOrMissingMessage()
                );

                throw new ConfigPropertyMissingException(propertyName, configFilePath);
            } else {
                log.info(
                    "optionalProperty->usingDefault property: {}, defaultValue: {}, configFilePath: {}",
                    new Object[]{propertyName, defaultValue, getConfigPathOrMissingMessage()}
                );

                return defaultValue;
            }
        }

        Source source = propertySource.get(propertyName);

        log.debug("value->found property: {}, value: '{}', source: {}, configFilePath: {}",
            new Object[]{propertyName, stringValue, source, getConfigPathOrMissingMessage()});

        Object value = null;

        // now attempt to parse the value into the type requested.  bail out on parse errors.
        if (Integer.class.equals(targetType)) {
            try {
                value = Integer.parseInt(stringValue);
            } catch (NumberFormatException e) {
                throwBadValue(stringValue, propertyName, targetType, source, e);
            }

        } else if (Boolean.class.equals(targetType)) {
            if ("true".equals(stringValue))
                value = true;
            else if ("false".equals(stringValue))
                value = false;
            else
                throwBadValue(stringValue, propertyName, targetType, source, null);

        } else if (String.class.equals(targetType)) {
            value = stringValue;

        } else {
            String message = String.format(
                "Don't know how to convert to type %s (on property %s).",
                targetType,
                propertyName
            );

            throw new RuntimeException(message);
        }

        return (T) value;
    }

    private static void throwBadValue(String stringValue, String propertyName, Class targetType, Source source, Throwable e) {
        String message = String.format(
            "Unable to parse value '%s' for %s property '%s' from source %s.",
            stringValue,
            targetType.getSimpleName(),
            propertyName,
            source == Source.FILE ? configFilePath : "system properties"
        );

        log.error("getProperty->badValue message: {}", message, e);
        throw new BadConfigPropertyValueException(message, e);
    }

    /**
     * Loads properties from the config file when available, and overlays these with system properties.
     */
    private static Properties resolveProperties() {
        Properties properties = new Properties();

        if (configFilePath != null) {
            log.info("configFile->load path: {}", configFilePath);

            File file = new File(configFilePath);

            if (!(file.isFile() && file.canRead())) {
                String message = String.format(
                    "Path provided in system property '%s' ('%s') is not that of a readable file.",
                    CONFIG_FILE_PATH_SYSTEM_PROPERTY,
                    configFilePath
                );

                log.error(message);
                throw new RuntimeException(message);
            }

            try {
                properties.load(new FileInputStream(file));
            } catch (Throwable e) {
                String message = String.format(
                    "Unable to load path provided in system property '%s' ('%s').",
                    CONFIG_FILE_PATH_SYSTEM_PROPERTY,
                    configFilePath
                );

                log.error(message, e);
                throw new RuntimeException(message, e);
            }
        }

        for (Object property : properties.keySet())
            propertySource.put((String) property, Source.FILE);

        properties.putAll(System.getProperties());

        for (Object property : System.getProperties().keySet())
            propertySource.put((String) property, Source.SYSTEM);

        return properties;
    }

    private static String getConfigPathOrMissingMessage() {
        return configFilePath != null ? configFilePath : "[none defined via -D" + CONFIG_FILE_PATH_SYSTEM_PROPERTY + "]";
    }
}
