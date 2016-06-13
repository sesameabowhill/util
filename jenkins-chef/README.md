=============
PREREQUISITES
=============
To run locally, you will need to create a CentOS 7 chef workstation.
This can be done in a Virtualbox if needed.

* Update your system before starting: 
~~~
sudo yum update
~~~~

It may also be worthwhile to open a firewall on your machine:
~~~
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload
~~~

============
INSTALL CHEF
============

Install Chef DevKit on your Chef Workstation

~~~
# obtain and install a new chef via web browser
wget https://packages.chef.io/stable/el/7/chefdk-0.13.21-1.el7.x86_64.rpm
rpm -ivh chefdk-0.13.21-1.el7.x86_64.rpm

# edit .bash-profile for build environment settings
eval "$(chef shell-init bash)"

# test chef build environment setting is correct
which ruby
/opt/chefdk/embedded/bin/ruby --version
chef-client --version
~~~

Edit Gemfile:
~~~
source "https://rubygems.org"

gem "test-kitchen"
gem "kitchen-docker"
gem "kitchen-vagrant"
gem "chef-sugar"
~~~

Run bundler 
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

====================
OBTAIN THIS COOKBOOK
====================

Copy the jenkinsjava folder from:
~~~
\\gibson\data\personal folders\abowhill\CHEF_PROJECTS\jenkinsjava
~~~
to your current working directory

===============
INSTALL JENKINS
===============


~~~
cd jenkinsjava
kitchen converge
~~~

  - installation will take about 10 min
  - verify by visiting jenkins home page
      http://172.17.0.2:8080
  - login as chef
  - no password

The following Jenkins plugins will installed automatically:
~~~
ant                     java make system
pam-auth                unix host auth method (v. 1.2)
junit                   java unit testing (v. 1.13, restart)
git                     integrates git (v. 2.4.4, restart)
git-client              git library for plugins
github                  integrates github
github-api              github API library
versionnumber           rich version numbers
credentials             manage credentials and groups (restart)
mailer                  smtp mailing (restart) 
email-ext               smtp mailing
matrix-auth             matrix authorization method
matrix-project          matrix authorization strategies
ssh-credentials         allows ssh cred storage (v 1.12)
plain-credentials       new creds, secret text (v 1.2)
ssh-agent               ssh-agent to builds
workflow-step-api       workflow pipline component (v 2.1)
external-monitor-job    interact and monitor jobs
maven-plugin            build via special project type (v 2.13, restart)
nodenamecolumn          Adds column showing node name
jobtype-column          Adds column showing job type
greenballs              Adds green balls icon
view-job-filters        mix and match filters
dashboard-view          portal view for jenkins
javadoc                 javadoc support (v 1.3)
instant-messaging       bot and build notifications for messanging
jabber                  jabber notifier for instant-messanging
artifactdeployer        shows artifacts on site and deploys
artifactory             interface to artifactory
copy-to-slave           copy files to slave and back
slave-setup             copy files to slaves before build
ssh-slaves              manage slaves over ssh
slave-status            monitor resource use on slave
slack                   post build notifications to slack channel
performance             capture reports from Jmeter and Junit
cobertura               code coverage report tool
envfile                 stores environment in a file
file-leak-detector      lists open file handles
scm-api                 SCM dependency (v 1.2)
script-security         script approval workflow (v 1.19)
token-macro             macro expansions (v 1.12.1)
~~~



===========
Upgrade GIT
===========

At this point, GIT must be upgraded to the latest version, or subsequent attempts to connect to github will not work.

~~~
# Login to the VM
kitchen login

# start
cd 
git --version     ## should read 1.7.0 or thereabout. 
                  ## this version is too old.
                  ## you will need at least 1.8.1

# make temp dir
mkdir temp
cd temp

# download new git
curl https://www.kernel.org/pub/software/scm/git/git-2.8.4.tar.gz > git-2.8.4.tar.gz
gzip -dc git-2.8.4.tar.gz | tar xvf -
cd git-2.8.4

# install depends - remove olds
sudo yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel
sudo yum install  gcc perl-ExtUtils-MakeMaker
sudo yum remove git

# build and install
make configure
./configure --prefix=/usr
sudo make install

# confirm
which git            # confirm it's /usr/bin/git
ls -alt `which git`  # look at install date 
git --version        # version should say 2.8.4 or whatever you downloaded

# cleanup
cd
sudo rm -rfv temp

# restart jenkins
sudo service jenkins restart
~~~

=========================
Global Tool Configuration
=========================

These are the locations of all the system tools installed for this to work.

Most of the values can be obtained by entering: 
~~~
mvn --version 
~~~
* Ignore the values for GIT for the moment 

Complete each section with information about what is installed on the system.

- JDK
   - uncheck "install automatically"
   - Name                      java-1.8.0_91-b14
   - JAVA_HOME                 /usr/lib/jvm/java-1.8.0
- Git
   - Name                      2.8.4
   - Path to Git Executable    /usr/bin/git
- Maven 
   - uncheck "install automatically"
   - Name                      maven-3.3.9
   - MAVEN_HOME                /usr/local/maven
- Click Save

---------------
GLOBAL SETTINGS
---------------

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
   Global Maven Opts: -Xmx1024m
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
            Description: (leave blank)
         Click Add
         Now you should see this token in credentials popdown.
          select it and click TEST CONNECTION
            it should say "credentials verified for ..."
         Uncheck Manage Hooks
Click Apply
~~~

~~~
Artifactory
   Check: Use Credentials Plugin
   Click: Add
   Artifactory Server ID: main
   URL: http://artifactory.sesamecom.com/artifactory
   Default Deployer Credentials
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
      check: use different resolver credentials
      select "jenkins/*****" from popdown
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

~~~
Global Slack Notifer Settings
   Team Subdomain                   sesamecom
   Outgoing Webhook Token           6My6VBHcvVxvAELFKL5o9Xd5
   Outgoing Webhook URL Endpoint    /
   Click Test 
Click Apply
~~~

End global configuration by Clicking SAVE

----------------
PROJECT SETTINGS
----------------
====================
SETTING UP A PROJECT
====================

Following are the project settings needed to get the sesame-api project
to build. First, you'll need to create the project.

Login to jenkins as chef - no password and select:

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

~~~
General 
   Maven Project Name: sesame-api-dev
   check Discard old builds
      log rotation strategy
      keep 2 builds
   check github project
   project URL: https://github.com/sesacom/sesame_api/
~~~

~~~
Source Code Management
   Check GIT
   Repositories
     repository URL: https://github.com/sesacom/sesame_api.git
       credentials:
          configure your own personal sesame creds here to access github
          click Add > Jenkins
             select: username with password
             enter username: <your sesame username>
             enter password: <your sesame password>
          select your creds from popdown (aka: <yourname>/*****)
     branch specifier: origin/dev
     repository browser: githubweb
     URL: https://github.com/sesamecom/web/
~~~

~~~
Build Triggers:
    check: Build whenever a SNAPSHOT dependency is built
    check: build periodically 
      (once every half hour schedule)
      enter schedule: H * * * *      
      Build when a change is pushed to GitHub
~~~

~~~
Build Environment:
    check Resolve artifacts from Artifactory
       select globally configured artifactory server from popdown
    override resolver credentials 
       select jenkins/*****
    click refresh repositories
~~~
~~~
Build:
    (ignore error message abotu missing pom)
    goals and options: 
         clean package -DsesameConfigurationFile=$WORKSPACE/../../sesame.properties -DpersistSchema=persist_web_master_snapshot -DanalyticsSchema=analytics_report_master_snapshot -DlogSchema=upload_logs
     Click Advanced
        Check: Use Private Maven Repository
        Select: Local to the workspace 
~~~
~~~     
Build Settings:
    check: e-mail notification
    email: eng-seattle@sesamecommunications.com
~~~
~~~
Post-steps
    select Add post-build-step
~~~
~~~   
Post-build actions:
   click: Add post-build action
   select: Aggragate downstream test results
   check: Automatically aggregate all downstream tests

   click: Add post-build action
   select: deploy artifacts to maven repository
   ckick advanced
      repo url: http://artifactory.sesamecom.com/artifactory/libs-sesame-api-local
         repo id : snapshots
         check: Assign unique versions to snapshots

   click: Add post-build action
   select: Slack Notifications
     <check all 7 visible items>
~~~
Click SAVE

