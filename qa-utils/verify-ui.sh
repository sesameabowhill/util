export DISPLAY=:1
log="/tmp/ui-test-$1.log"
echo "output to $log"
java -cp /home/sites/artifacts/member-migration-jar-with-dependencies.jar -DskipLiquibaseUpdate=true -DsesameConfigurationFile=/home/sites/wrapper/conf/migration/sesame.properties -Dlogback.configurationFile=/home/sites/wrapper/conf/migration/logback.xml com.sesamecom.migration.UiAutomationTestMain $1 | tee $log
