package com.sesamecom.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.FileInputStream;
import java.util.Properties;

import static com.sesamecom.common.ConfigRequirementType.OPTIONAL;
import static com.sesamecom.common.ConfigRequirementType.REQUIRED;

/**
 * Globally defines and provides read only access to per-environment configuration properties for sesame components.
 * <p/>
 * Properties are optionally read at class initialization from a file at the path defined by the system property
 * sesameConfigurationFile.  The same properties can be defined directly using system properties, which will override
 * values in sesameConfigurationFile.  Changes to this properties file are only picked up on JVM restart.
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
    private static final String CONFIG_FILE_PATH = System.getProperty(CONFIG_FILE_PATH_SYSTEM_PROPERTY);

    private static enum Source {SYSTEM, FILE}

    private static final Properties configFileProperties = loadConfigFileProperties();

    /**
     * The hostname of the MySQL instance to connect to for access to the analytics database.
     * <p/>
     * Property: analyticsHost
     */
    public static String getAnalyticsHost(String defaultValue) {
        return (String) getProperty("analyticsHost", String.class, OPTIONAL, defaultValue);
    }

    public static String getAnalyticsHost() {
        return (String) getProperty("analyticsHost", String.class);
    }

    /**
     * The port of the MySQL instance to connect to for access to the analytics database.
     * <p/>
     * Property: analyticsPort
     */
    public static Integer getAnalyticsPort(Integer defaultValue) {
        return (Integer) getProperty("analyticsPort", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getAnalyticsPort() {
        return (Integer) getProperty("analyticsPort", Integer.class);
    }

    /**
     * The schema on the MySQL instance to use for access to the analytics database.
     * <p/>
     * Property: analyticsSchema
     */
    public static String getAnalyticsSchema(String defaultValue) {
        return (String) getProperty("analyticsSchema", String.class, OPTIONAL, defaultValue);
    }

    public static String getAnalyticsSchema() {
        return (String) getProperty("analyticsSchema", String.class);
    }

    /**
     * The username to use when connecting to the analytics database.
     * <p/>
     * Property: analyticsUser
     */
    public static String getAnalyticsUser(String defaultValue) {
        return (String) getProperty("analyticsUser", String.class, OPTIONAL, defaultValue);
    }

    public static String getAnalyticsUser() {
        return (String) getProperty("analyticsUser", String.class);
    }

    /**
     * The password to use when connecting to the analytics database.
     * <p/>
     * Property: analyticsPassword
     */
    public static String getAnalyticsPassword(String defaultValue) {
        return (String) getProperty("analyticsPassword", String.class, OPTIONAL, defaultValue);
    }

    public static String getAnalyticsPassword() {
        return (String) getProperty("analyticsPassword", String.class);
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

    public static Boolean getAnalyticsEtlUseInsertIntoSelectFrom() {
        return (Boolean) getProperty("analyticsEtlUseInsertIntoSelectFrom", Boolean.class);
    }

    /**
     * How many records to put in each batched insert in the analytics ETLs.  Only effects fact table loading when
     * analyticsEtlUseInsertIntoSelectFrom is false, but always effects dimension table loading.
     * <p/>
     * Property: analyticsEtlBatchSize
     */
    public static Integer getAnalyticsEtlBatchSize(Integer defaultValue) {
        return (Integer) getProperty("analyticsEtlBatchSize", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getAnalyticsEtlBatchSize() {
        return (Integer) getProperty("analyticsEtlBatchSize", Integer.class);
    }

    /**
     * How many records to insert during one transaction in the analytics ETLs.  Only effects fact table loading when
     * analyticsEtlUseInsertIntoSelectFrom is false, but always effects dimension table loading.
     * <p/>
     * Property: analyticsEtlTransactionSize
     */
    public static Integer getAnalyticsEtlTransactionSize(Integer defaultValue) {
        return (Integer) getProperty("analyticsEtlTransactionSize", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getAnalyticsEtlTransactionSize() {
        return (Integer) getProperty("analyticsEtlTransactionSize", Integer.class);
    }

    /**
     * Concurrency level to use for ETLs.  Corresponds to number of simultaneous database connections and queries.
     * <p/>
     * Property: analyticsEtlConcurrencyCount
     */
    public static Integer getAnalyticsEtlConcurrencyCount(Integer defaultValue) {
        return (Integer) getProperty("analyticsEtlConcurrencyCount", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getAnalyticsEtlConcurrencyCount() {
        return (Integer) getProperty("analyticsEtlConcurrencyCount", Integer.class);
    }

    /**
     * How many days worth of data to refresh when doing ranged refreshes.
     * <p/>
     * Property: analyticsEtlRefreshDayRange
     */
    public static Integer getAnalyticsEtlRefreshDayRange(Integer defaultValue) {
        return (Integer) getProperty("analyticsEtlRefreshDayRange", Integer.class, OPTIONAL, defaultValue);
    }

    public static Integer getAnalyticsEtlRefreshDayRange() {
        return (Integer) getProperty("analyticsEtlRefreshDayRange", Integer.class);
    }

    /**
     * The Camel endpoint to listen for ad-hoc ETL commands on.
     * <p/>
     * Property: analyticsEtlAdHocCommandEndpoint
     */
    public static String getAnalyticsEtlAdHocCommandEndpoint() {
        return (String) getProperty("analyticsEtlAdHocCommandEndpoint", String.class);
    }

    /**
     * Provides raw, read-only access to all properties defined.  This can be useful when some properties are used to
     * configure a third party component that knows how to get them from a Properties object.
     */
    public Properties getProperties() {
        // TODO: needed for e.g. BoneCP!
        return null;
    }

    private static Object getProperty(String propertyName, Class targetType) {
        return getProperty(propertyName, targetType, REQUIRED, null);
    }

    /**
     * Gets and parses a property given name, type, and requirementType.  Throws ConfigPropertyMissingException if a
     * requirement type is REQUIRED and no value is defined, BadConfigPropertyValueException if a value is defined but
     * cannot be parsed, and RuntimeException if the type specified is not supported.
     */
    private static Object getProperty(String propertyName, Class targetType, ConfigRequirementType requirementType, Object defaultValue) {
        String systemValue = System.getProperty(propertyName);
        String fileValue = configFileProperties.getProperty(propertyName);

        // first determine where the value is coming from: config file or system properties
        Source source;
        String stringValue;
        if (systemValue != null) {
            stringValue = systemValue;
            source = Source.SYSTEM;
        } else {
            stringValue = fileValue;
            source = Source.FILE;
        }

        // bail out if we can't find it and it's required, return defaultValue if only the former.
        if (stringValue == null) {
            if (ConfigRequirementType.REQUIRED.equals(requirementType)) {
                log.error(
                    "requiredProperty->missing property: {}, configFilePath: {}",
                    propertyName,
                    CONFIG_FILE_PATH
                );

                throw new ConfigPropertyMissingException(propertyName, CONFIG_FILE_PATH);
            } else {
                log.info(
                    "optionalProperty->usingDefault property: {}, defaultValue: {}, configFilePath: {}",
                    new Object[]{propertyName, defaultValue, CONFIG_FILE_PATH}
                );

                return defaultValue;
            }
        }

        log.debug("value->found property: {}, value: '{}', source: {}, configFilePath: {}",
            new Object[]{propertyName, stringValue, source, CONFIG_FILE_PATH});

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

        return value;
    }

    private static void throwBadValue(String stringValue, String propertyName, Class targetType, Source source, Throwable e) {
        String message = String.format(
            "Unable to parse value '%s' for %s property '%s' from source %s.",
            stringValue,
            propertyName,
            targetType.getSimpleName(),
            source == Source.FILE ? CONFIG_FILE_PATH : "system properties"
        );

        log.error("getProperty->badValue message: {}", message, e);
        throw new BadConfigPropertyValueException(message, e);
    }

    /**
     * Loads properties from the config file when available.  Throws RuntimeException if one is specified by cannot be
     * loaded.
     */
    private static Properties loadConfigFileProperties() {
        Properties properties = new Properties();

        if (CONFIG_FILE_PATH != null) {
            log.info("configFile->load path: {}", CONFIG_FILE_PATH);

            File sesameConfigurationFile = new File(CONFIG_FILE_PATH);

            if (!(sesameConfigurationFile.isFile() && sesameConfigurationFile.canRead())) {
                String message = String.format(
                    "Path provided in system property '%s' ('%s') is not that of a readable file.",
                    CONFIG_FILE_PATH_SYSTEM_PROPERTY,
                    CONFIG_FILE_PATH
                );

                log.error(message);
                throw new RuntimeException(message);
            }

            try {
                properties.load(new FileInputStream(sesameConfigurationFile));
            } catch (Throwable e) {
                String message = String.format(
                    "Unable to load path provided in system property '%s' ('%s').",
                    CONFIG_FILE_PATH_SYSTEM_PROPERTY,
                    CONFIG_FILE_PATH
                );

                log.error(message, e);
                throw new RuntimeException(message, e);
            }
        }

        return properties;
    }
}

