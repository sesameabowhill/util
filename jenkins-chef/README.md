=============
PREREQUISITES
=============
To run locally, you will need to being running a CentOS Xwindows installation to make into a Chef Workstation. Chef scripts generally need to be developed on a dedicated workstation. This can be done in a Virtualbox if needed.

* Update your OS before starting: 
~~~
sudo yum update
~~~~

It may also be worthwhile to open a firewall on your machine:
~~~
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload
~~~

====================
OBTAIN THIS COOKBOOK
====================

Make a working directory.
Git clone the sesame utilities folders to your current working directory:

~~~
git clone git@github.com/sesacom/util.git
~~~

============
INSTALL CHEF
============

Install the Chef Development Kit

The Chef DK goes on your workstation. 

~~~
# obtain and install a new chef archive
wget https://packages.chef.io/stable/el/7/chefdk-0.13.21-1.el7.x86_64.rpm
rpm -ivh chefdk-0.13.21-1.el7.x86_64.rpm

# edit .bash-profile for build environment settings
eval "$(chef shell-init bash)"

# verify the chef build environment settings are correct
which ruby
/opt/chefdk/embedded/bin/ruby --version
chef-client --version
~~~

Run Ruby Bundler 
~~~
bundle install
~~~

==============
INSTALL DOCKER
==============
Update your system:
~~~
sudo yum update
~~~

Verify requisite dependencies are installed:
~~~
ls -l /sys/class/misc/device-mapper  (should show files)
sudo rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
~~~

Follow these instructions to install Docker:
~~~
https://docs.docker.com/engine/installation/linux/centos/
~~~


===============
INSTALL JENKINS
===============

~~~
cd jenkinsjava
kitchen converge
~~~

NOTE: Numerous Jenkins plugins will installed automatically

- installation will take about 10 min
- verify by visiting jenkins home page
  http://172.17.0.2:8080
- login will be authenticated through github, so authenticate with your Github username and password.


NOTE ABOUT MODULES:
-------------------
- Occasionally modules break build settings in subtle ways. For example, Version 2.5.0 of the Git
  module creates git problems early in builds. If you revert to the previous version of the module
  the problem goes away. If problems are detected, the module will be left not-upgraded in the 
  module manager.


==================================
Jenkins Global Tool Configuration
==================================

These are the locations of all the system tools installed for this to work.

Most of the values can be obtained by entering the following on the virtual machine after building it (kitchen login): 
~~~
mvn --version 
~~~

In Jenkins > Manage Jenkins > Global Tool Configuration, complete each section with information about what is installed on the system.

- JDK
   - click Add JDK
   - uncheck "install automatically"
   - Name                      java-1.8.0_91-b14
   - JAVA_HOME                 /usr/lib/jvm/java-1.8.0
- Git
   - Name                      2.8.4
   - Path to Git Executable    /usr/bin/git
- Maven 
   - click Add Maven
   - uncheck "install automatically"
   - Name                      maven-3.3.9
   - MAVEN_HOME                /usr/local/maven
- Click Save


------------------------
JENKINS CONFIGURE SYSTEM
------------------------

Global settings provide defaults for project settings. 
The following settings are grouped by section of Global configuration: 

Jenkins > Manage Jenkins > Configure System

Go through each of the sections below and enter or cut-and-paste data into
the corresponding Jenkins configuration fields. Sections are easily located 
directly under the Jenkins logo at the top of the page. Hover over the 
"Jenkins > configuration" item, and click on the triangle. This will expose
section names listed below.

~~~
Maven Project Configuration
   Jenkins Location
      System Admin e-mail address: jenkins@sesamecommunications.com
click Apply
~~~

~~~
Github
Github Servers
   Click Add
      API URL: https://api.github.com
      Credentials: MySecretText
         (NOTE: if this doesn't exist, perform the following sub-steps)
      Click ADD > Jenkins
         Under KIND, select Secret Text
         In the SECRET field, enter  your real Gitub access token from:
            https://github.com/settings/tokens
            (generate new token under your username if you don't have one)
            (otherwise use mine, for user sesameabowhill:)
               7e26fb3e9cd207a5ccc85f399f8502167e6c762d
            Secret: <token>
         Click Add
         Now you should see this token in credentials popdown.
          select it and click TEST CONNECTION
            it should say "credentials verified for ..."
         Uncheck Manage Hooks
Click Apply
~~~


NOTE: In the following section, if credentials controls do not appear, click SAVE and re-enter the configuration again. They will re-appear.
~~~
Artifactory
   Check: Use Credentials Plugin
   Click: Add
   Artifactory Server ID: main
   URL: http://artifactory.sesamecom.com/artifactory
   Default Deployer Credentials
      (save settings and re-enter if the following doesn't show)
      select "jenkins/*****" from popdown
      IF such a selection is not there do the following:
         click Add > Jenkins
         select: Username with password
         enter username: Jenkins
         enter password: 
\{DESede\}r3kV1LVjU7osjr73Z+LjwdptISVysRNdDdUFvLG79e9qhuHdm9p4uw==
      click Add
      select "jenkins/*****" from popdown
      click: Test Connection
         should return: Found Artifactory 2.4.2
Click Apply
~~~

~~~
Git Plugin
   Global Config user.name Value: jenkins
   Global Config user.email Value: jenkins@sesamecommunications.com
Click Apply
~~~

~~~
Extended E-mail Notification
   SMTP server
      smtp2.sesamecommunications.com
   Default user e-mail suffix
      @sesamecommunications.com
Click Apply
~~~

End global configuration by Clicking SAVE

------------------------
JENKINS PROJECT SETTINGS
------------------------
====================
SETTING UP A PROJECT
====================

Following are the project settings needed to get the sesame-api project
to build. First, you'll need to create the project.

Login to jenkins

~~~
New Item
   Enter "sesame-api-dev" in the field at the top of the page
   Select "Maven Project" from the list
click OK
~~~

You will be brought into the sesame-api-dev project configuration page, 
but can always return to it by pathing to:

Jenkins > sesame-api-dev (clickable text) > configure

Each of the following sections are listed in the navigation tabs at the 
top of the page. It is recommended to click "Apply" after completing each
section, then finally clicking "Save" when all sections are complete.

General 
~~~
   Maven Project Name: sesame-api-dev
   check Discard old builds
      log rotation strategy
      keep 2 builds
   check github project
   project URL: https://github.com/sesacom/sesame_api/
~~~

Source Code Management
~~~
   Check GIT
   Repositories
     repository URL: https://github.com/sesacom/sesame_api.git
       credentials:
          configure your own personal GIT sesame creds here to access github
          click Add > Jenkins
             select: Git username with password
             enter username: <your Git username>
             enter password: <your Git  password>
          select your creds from popdown (aka: <yourname>/*****)
     branch specifier: */jenkins-test-branch
     repository browser: githubweb
     URL: https://github.com/sesamecom/web/
~~~

Build Triggers:
~~~
    check: Build whenever a SNAPSHOT dependency is built
           Build when a change is pushed to GitHub
~~~

Build:
~~~
    goals and options: 
       clean package -gs ../../settings.xml -DsesameConfigurationFile=../../sesame.properties -DpersistSchema=md_snapshot -DanalyticsSchema=analytics_report_master_snapshot -DlogSchema=upload_logs
    click advanced
       Check: Use Private Maven Repository
       Select: Local to the workspace 
~~~

Build Settings:
~~~     
    check: e-mail notification
    email: eng-seattle@sesamecommunications.com
~~~

Post-build actions:
~~~   
   click: Add post-build action
   select: Aggragate downstream test results
   check: Automatically aggregate all downstream tests
~~~
Click SAVE

------------------------
MANUAL SETUP FOR COMPILE
------------------------
====================
sesame-api project
====================

There is one project that will be initially configured with Jenkins with Java 8, and this is the sesame-api project. Below is the procedure for setting up a manual build environment for sesame-api in the UNIX console. This can serve as a model to instruct on how to test and add additional jobs to Jenkins.

The easiest way to setup a manual build is to deploy Jenkins to a VM using this cookbook and the command:
~~~
kitchen converge
~~~

If you login to the VM using ```kitchen login``` all dependencies will be established with the correct values for a manual build.

~~~ shell
cd
mkdir temp
cd temp
(perform UPGRADE GIT steps listed near staret of this document)
git clone -b jenkins-test-branch https://github.com/sesacom/sesame_api.git
git clone https://github.com/sesacom/util.gi
mysql -u root <  util/jenkins-chef/templates/default/create_mysql_tables.erb 
cd sesame-api
mvn clean deploy -gs ../util/jenkins-chef/templates/default/settings.xml -DsesameConfigurationFile=../util/jenkins-chef/templates/default/sesame.properties
~~~

This cookbook will not work on On Centos 7, due to systemd changes.
In this case you will need to perform the following steps beforehand:

~~~
# install mariadb or mysql
sudo yum -y install mariadb-server mariadb
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql_secure_installation
sudo yum install java-1.8.0-openjdk-devel.x86_64
sudo yum install 
~~~

Installing the default Java and Git are fine for CentOS7