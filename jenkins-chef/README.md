=============
PREREQUISITES
=============
To run locally, you will need to being running a CentOS Xwindows installation to make into a Chef Workstation. Chef scripts generally need to be developed on a dedicated workstation. This can be done in a Virtualbox if needed.

Update your packages: 
~~~
sudo yum update
~~~

It may also be worthwhile to open a firewall on your machine:
~~~
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload
~~~

====================
OBTAIN THIS COOKBOOK
====================

Git clone the sesame utilities folders to a directory called SESACOM

~~~
git clone git@github.com/sesacom/util.git SESACOM
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

In Jenkins > Manage Jenkins > Global Tool Configuration

- Git
   - Name                      2.8.4
   - Path to Git Executable    /usr/bin/git
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

Run the script: ``/var/lib/jenkins/jobs/manual_build.sh```

On CentOS 7, this Docker-based cookbook will not work due to systemd revisions. In this case you will need to perform the following steps beforehand:

~~~
# install mariadb or mysql
sudo yum -y install mariadb-server mariadb
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql_secure_installation
~~~

Installing the default Java and Git are fine for CentOS7


Better yet, for CentOS 7, clone the VirtualBox version of this cookbook. VirtualBox works with CentOS 7, but performs more slowly.


----------
API ACCESS
----------

Since Oauth will not allow standard login access, you have to use an API key after logging in via Oauth to use Jenkins' RESTful API. To do this, in your normal web browser visit http://<jenkins-server>/user/<username>/configure and copy your user API token from there.

Example:
~~~
(if your Github username is barney, and your Jenkins server name is wilma)
http://wilma:8080/user/barney/configure
<click "Show API Token" Button>
<copy Token to clipboard>
~~~

At that point, you should be able to access the Jenkins API with curl:

~~~
# return a list of Jenkins users in XML
curl -X POST barney:198012acc88999fac09098090988aa@wilma:8080/asynchPeople/api/xml
~~~

~~~
# list all installed plugins using XML API [1]
JENKINS_HOST=barney:c12cf5da8b3bb0eb3389247ca29bb116@wilma:8080
curl -sSL "http://$JENKINS_HOST/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" | perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1 \2\n/g'|sed 's/ /:/'
~~~
[1] https://github.com/fabric8io/jenkins-base/blob/master/README.md

~~~
# [2] Create a job 
JENKINS_HOST=barney:c12cf5da8b3bb0eb3389247ca29bb116@wilma:8080
curl -X POST -H "Content-Type:application/xml" -d "<project><builders/><publishers/><buildWrappers/></project>" "http://${JENKINS_HOST}/createItem?name=AA_TEST_JOB2"
~~~
[2] http://stackoverflow.com/questions/15909650/create-jobs-and-execute-them-in-jenkins-using-rest

---------------
RUNNING SCRIPTS
---------------

One way to run scripts in the Jenkins JVM insdtance from outside that instance is to use the script API offered at /script. This is actually a call to the view that displays the Groovy console so the response to script runs will contain a lot of redundant HTML on return. This method is a bit less desirable for automation, because it is more like you are injecting a Groovy script into a Jenkins web page with a Groovy console on it, then extracting the results from HTML normally returned by the web server. It may take some extra work to extract returned data. However it will, execute whatever you hand it.

~~~
curl -d 'script=println(Jenkins.instance.pluginManager.plugins)' http://barney:8187218182371823718237123@wilma:8080/script > 123.html
~~~

Again, this command can be issued after obtaining an API key for the user _barney_ on the server _wilma_.
Below is a similar command that takes an external _groovy_ program filename to execute:

Suppose we have a groovy script called addmaven.groovy in the current directory, to add new settings to the current maven installation in Global Tools Configuration:
~~~
a=Jenkins.instance.getExtensionList(hudson.tasks.Maven.DescriptorImpl.class)[0];
b=(a.installations as List);
b.add(new hudson.tasks.Maven.MavenInstallation("maven-3.3.9", "/usr/local/maven", []));
a.installations=b
a.save()
~~~

If we execute the following 

~~~
curl --user 'barney:8187218182371823718237123' --data-urlencode "script=$(<./myscript.groovy)" http://172.17.0.2:8080/scriptText
~~~

We get the fields filled for the Maven tool location in the Global Tools Configuration view.


