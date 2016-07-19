========
VERSIONS
========

The main branch of this project is designed to install Jenkins on CentOS 6.8 using Docker for development purposes.
If you need a dev installation to work on CentOS 7, clone the centos7 branch of utils.

The CentOS 7 branch version lags further behind featurewise and uses vbox which is slower than docker.
Using the centos7 branch you may need to perform the following steps manually to prepare mysql:
~~~
# install mariadb or mysql
sudo yum -y install mariadb-server mariadb
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql_secure_installation
~~~

Irrespective of development branch versions, this project aims to keep pace with whichever OS currently in use.

=============
PREREQUISITES
=============
Chef scripts should be developed and tested on a dedcated workstation, called a _Chef Workstation_. You can run this project locally on a Centos-7.x machine or a Windows machine running VirtualBox under a CentOS-7 image. Within CentOS-7, the Jenkins installation itself will be run on a centos-6.8 virtual Docker machine, and will be accessible on completion using a local web browser on ```http://172.17.0.2:8080```. Since the Jenkins installation authenticates via Github, you will be asked by Github to provide your Sesame Github username and password. All other accesses will be blocked.

A CentOS-7 installation can be obtained via https://wiki.centos.org/Download . The DVD ISO should work.

Once your CentOS-7 host is installed on a machine or VirtualBox machine, update your packages: 
~~~
sudo yum update
~~~

It may also be worthwhile to open a firewall:
~~~
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload
~~~

====================
OBTAIN THIS COOKBOOK
====================

Git clone the sesame utilities folders to a directory, for example, one called SESACOM

~~~
git clone git@github.com/sesacom/util.git SESACOM
~~~

This project will be under SESACOM/utils/jenkins-chef, which is where you will eventually run ```kitchen converge``` to install Jenkins.

============
INSTALL CHEF
============

But first, you will need to install the Chef Development Kit in your copy of CentOS-7.

~~~
# remove iany previous version of chefdk
rpm -e chefdk

# obtain and install a new chef archive
wget https://packages.chef.io/stable/el/7/chefdk-0.15.16-1.el7.x86_64.rpm
rpm -ivh chefdk-0.15.16-1.el7.x86_64.rpm

# edit .bash-profile for build environment settings
eval "$(chef shell-init bash)"

# verify the chef build environment settings are correct (should return reasonable values)
which ruby
/opt/chefdk/embedded/bin/ruby --version
chef-client --version
~~~

Next, run Ruby Bundler
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

Finally, follow these instructions to install Docker:
~~~
https://docs.docker.com/engine/installation/linux/centos/
~~~

At this point, your CentOS-7 Chef Workstation is ready to run chef cookbooks.

===============
INSTALL JENKINS
===============

To install Jenkins, just change to the jenkins-chef project directory and run ```kitchen converge```. 

~~~
cd SESACOM/utils/jenkins-chef
kitchen converge
~~~

NOTE: A lot of software gets upgraded and built, and numerous Jenkins plugins will installed automatically
so there may be periods of apparent inactivity lasting 5 minutes or more at some stages. Just let it run, or 
login (if the converge has progressed through the initial stages) with ```kitchen login``` to perform a ```ps auxwww``` to view process mechanics.

- installation will take about 30 min
- verify by visiting jenkins home page
  http://172.17.0.2:8080
- login will be authenticated through github, so authenticate with your Github username and password.


NOTE ABOUT MODULES:
-------------------
- Occasionally modules break build settings in subtle ways. For example, Version 2.5.0 of the Git
  module creates git problems early in builds. If you revert to the previous version of the module
  the problem goes away. If problems are detected, the module will be left not-upgraded in the 
  module manager, so some Jenkins modules will appear to be not upgraded.


NOTE: Although the installation of Jenkins is automatic, the configuration of Jenkins is only partly-automated, 
and currently being developed. Below, are a list of steps required to fully configure Jenkins. Three main sections
are covered:

- Global Tool Configuration (automation complete)
- Global Jenkins System Configuration (automation partial)
- sesame-api job configuration (not automated)

==================================
Jenkins Global Tool Configuration
==================================
Under Jenkins > Manage Jenkins > Global Tool Configuration

Done automatically.

----------------------------
GLOBAL SYSTEM CONFIGURATION
----------------------------

Global settings provide defaults for all project settings. 
The following settings are grouped by section of Global configuration: 

Jenkins > Manage Jenkins > Configure System

Go through each of the sections below and enter or cut-and-paste data into
the corresponding Jenkins configuration fields. Sections are easily located 
directly under the Jenkins logo at the top of the page. Hover over the 
"Jenkins > configuration" item, and click on the triangle. This will expose
section names listed below.


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

---------------------------
SESAME-API PROJECT SETTINGS
---------------------------

Following are the project settings for the sesame-api project.
First, you'll need to create the project.

Jenkins > New Item

~~~
New Item
   Enter "sesame-api-dev" in the field at the top of the page
   Select "Maven Project" from the list
click OK
~~~

You will be brought into the sesame-api-dev project configuration page, 
but can always return to it by pathing to:

Jenkins > sesame-api-dev (clickable text mid-page) > configure

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

This completes Jenkins setup with the sesame-api project preinstalled.
You should be able to build a harmless development version of sesame-api by navigating to:

Jenkins > sesame-api-dev (clickable text mid-page) > Build Now


-------------------------------------
MANUAL SETUP FOR COMPILING SESAME-API
-------------------------------------
The sesame-api project is initially configured with this installation of Jenkins. However, the project changes a lot and sometimes the build may go out of sync with what developers are currenly using. In case you want to test comple sesame-api in a UNIX console without the aid of Jenkins, a shell script has been provided to verify the build and perform the same steps Jenkins would use to build the artifacts.

If you login to the Jenkins iinstance using ```kitchen login``` all dependencies will be established with the correct values for a manual build using the shell script.

Run the script: ``/var/lib/jenkins/jobs/manual_build.sh```

----------------
API ACCESS NOTES
----------------
This section is for people who want to perform various automation tasks with Jenkins.

Since Oauth will not allow standard login access, you have to use an API key after logging in via Oauth to use Jenkins' RESTful API. To do this, in your normal web browser visit ```http://<jenkins-server>/user/<username>/configure``` and copy your user API token from there.

Example:
~~~
(if your Github username is barney, and your Jenkins server name is wilma)
http://wilma:8080/user/barney/configure
<click "Show API Token" Button>
<copy Token to clipboard>
~~~

At that point, you should be able to access the Jenkins API with curl from the UNIX prompt:

~~~
# return a list of Jenkins users in XML
curl -X POST barney:198012acc88999fac09098090988aa@wilma:8080/asynchPeople/api/xml
~~~
========
EXAMPLES
========

This command will list all installed Jenkins Plugins:
~~~
# list all installed plugins using XML API [1]
JENKINS_HOST=barney:c12cf5da8b3bb0eb3389247ca29bb116@wilma:8080
curl -sSL "http://$JENKINS_HOST/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" | perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1 \2\n/g'|sed 's/ /:/'
~~~
[1] https://github.com/fabric8io/jenkins-base/blob/master/README.md


This command will create a new Job:
~~~
# [2] Create a job 
JENKINS_HOST=barney:c12cf5da8b3bb0eb3389247ca29bb116@wilma:8080
curl -X POST -H "Content-Type:application/xml" -d "<project><builders/><publishers/><buildWrappers/></project>" "http://${JENKINS_HOST}/createItem?name=AA_TEST_JOB2"
~~~
[2] http://stackoverflow.com/questions/15909650/create-jobs-and-execute-them-in-jenkins-using-rest

---------------
RUNNING SCRIPTS
---------------

One way to run scripts in the Jenkins JVM instance from outside that instance is to use the script API offered at /script. 

This is actually a call to the view that displays the Groovy console. So the response will contain a lot of redundant HTML on return. This method is a bit less desirable for automation, because you are injecting a Groovy script into a Jenkins web page with a Groovy console on it, then extracting the results from HTML normally returned by the web server to a web browser. It may take some extra work to extract returned data. However it will execute whatever you hand it.

~~~
curl -d 'script=println(Jenkins.instance.pluginManager.plugins)' http://barney:c12cf5da8b3bb0eb3389247ca29bb116@wilma:8080/script > 123.html
~~~

Again, this command can be issued after obtaining an API key for the user _barney_ on the server _wilma_.
Below is a similar command that takes an external _groovy_ program filename to execute, rather than inline code:

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
curl --user 'barney:c12cf5da8b3bb0eb3389247ca29bb116' --data-urlencode "script=$(<./myscript.groovy)" http://wilma/scriptText
~~~

We get the fields filled for the Maven tool location in the Global Tools Configuration view.


