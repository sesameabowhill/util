#!/usr/bin/sh
export MAVEN_OPTS="-Xmx4096m"
echo "Artifactory Username:"
read artifactory_user
echo "Artifactory Password:"
read -s artifactory_pass
cd
rm -rfv temp .m2/repository
mkdir temp
cd temp
git clone -b dev https://${artifactory_user}:${artifactory_pass}@github.com/sesacom/sesame_api.git
git clone https://${artifactory_user}:${artifactory_pass}@github.com/sesacom/util.git
cd sesame_api
mysql -h 127.0.0.1 -u root --password=sesame <  ../util/jenkins-chef/templates/default/create_mysql_tables.erb
echo "In another window, tail -f log.out to view build progress"
mvn clean install -gs ../util/jenkins-chef/templates/default/settings.xml -DsesameConfigurationFile=../util/jenkins-chef/templates/default/sesame.properties 2>&1 > log.out
