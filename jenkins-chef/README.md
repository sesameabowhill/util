=====
ABOUT
=====

This project is designed to install a Jenkins system that will ultimately replace the existing one at http://jenkins.sesamecommunications.com. 

The existing production version of Jenkins is over 5 years old and is a manually-maintained installation on a physical machine with a kernel date of 2011. The software on this machine is so out of sync, it cannot be upgraded safely.

The purpose of this project is to create a replacement installation that is 

1. Similar to the existing Jenkins in features 
2. Fully replicable 
3. Uses all new, modern up-to-date tools and modules
4. Is deployable to any kind of server, including cloud
5. Builds software on Java 8

This cookbook installs all-new versions of the following software:

- Jenkins
- Jenkins Modules
- Java 8
- Maven
- Git

It also uses Oauth validation via Github and does not store system passwords of users. If you have a Github Sesacom account, you will be able to access this system.

========
VERSIONS
========

The main branch of this project is designed to install Jenkins on CentOS 6.8 using Docker for development purposes. This should run fine locally on CentOS 7 Chef Workstation or a CentOS 6.x machine. If deployment on CentOS 7 is required, check out the centos7 branch of this project. It currently lags behind the master branch.

=============
PREREQUISITES
=============

Chef scripts should be developed and tested on a dedcated workstation, called a _Chef Workstation_. You can run this project locally on a Centos-7.x machine or a Windows machine running VirtualBox using a CentOS-7 image. 

Within CentOS-7, the Jenkins installation itself will deploy to a centos-6.8 virtual Docker machine, and will be accessible on completion using a local web browser on ```http://172.17.0.2:8080```. Since the Jenkins installation authenticates via Github, you will be asked by Github to provide your Sesame Github username and password. All other access will be blocked.

So the first step is to build yourself a CentOS-7 Chef Workstation.

A CentOS-7 installation can be obtained via https://wiki.centos.org/Download. The DVD ISO should work.
In the setup wizard, select X-Windows and Server - the combined version - as you will need both. 
Other software you choose to install won't matter.

Once your CentOS-7 host is prepared on a fresh physical machine or fresh VirtualBox machine, update your packages: 
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

Next step is to install Git. 
~~~
sudo yum install git
~~~

Clone the sesame utilities folders to a directory, for example, one called SESACOM
(use your sesame Git username and Password)
~~~
mkdir SESACOM
cd SESACOM
git clone https://<sesame_git_username>:<sesame_git_password>@github.com/sesacom/util.git SESACOM
cd SESACOM/utils/jenkins-chef
~~~

This installtion project will be under SESACOM/utils/jenkins-chef.

============
INSTALL CHEF
============

Once CentOS 7 is on, you will need to install the Chef Development Kit.

~~~
# remove iany previous version of chefdk
rpm -e chefdk

# obtain and install a new chef archive
wget https://packages.chef.io/stable/el/7/chefdk-0.15.16-1.el7.x86_64.rpm
rpm -ivh chefdk-0.15.16-1.el7.x86_64.rpm

# run this, but also add it afterwards to .bash-profile for proper future build environment settings
eval "$(chef shell-init bash)"

# verify the chef build environment settings are correct (each should return reasonable values)
which ruby
/opt/chefdk/embedded/bin/ruby --version
chef-client --version
~~~

Next, run Ruby Bundler. 

Ruby should be on the path if you ran ```eval "$(chef shell-init bash)"```
~~~
cd ~/SESACOM/utils/jenkins-chef
bundle install
~~~

==============
INSTALL DOCKER
==============

The next step is to install Docker.

Verify requisite dependencies are installed:
~~~
ls -l /sys/class/misc/device-mapper  (should show files. If not, download this:)
sudo rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
~~~

Finally, follow these instructions to install Docker.
~~~
https://docs.docker.com/engine/installation/linux/centos/
~~~

At this point, your CentOS-7 Chef Workstation is ready to run chef cookbooks, including this one.

===============
INSTALL JENKINS
===============

Last, run:

~~~
cd SESACOM/utils/jenkins-chef
kitchen converge
~~~

The installation and configuration takes about 10-30 minutes, you should be able to access the completed installation at ```http://172.17.0.2:8080```.  Your login will be authenticated through github, so authenticate with your Github username and password.


- You can dispose of the whole installation by issuing a ```kitchen destroy```. 
- You can login to the virtual machine running Jenkins using ```kitchen login``` or ssh as kitchen to the machine address with the password ```kitchen```.
- You can test the installation by building the inluded mock job of the sesame-api project. Click 'sesame-api' then 'build now'. This is a special demo/test branch.


----------------
MAKING A PROJECT
----------------
Project settings can be created in a config.xml and uploaded to Jenkins with curl. If you want to submit your own build project, do the following:
~~~
curl -X POST -H "Content-Type:application/xml" -d @config.xml <username>:<password>@172.17.0.2:8080/createItem?name=sesame-api
~~~
Substitute your own Github username and password.
config.xml is the project configuration, and should refer to module settings for mods that have already been installed globally.

-------------------------------------
MANUAL SETUP FOR COMPILING SESAME-API
-------------------------------------
The sesame-api project is initially configured for Jenkins. However, the project changes a lot and sometimes the build may go out of sync with what developers are currenly using. In case you want to test comple sesame-api in a UNIX console without the aid of Jenkins, a shell script has been provided to verify the build and perform the same steps Jenkins would use to build the artifacts.

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


CentOS 7 Notes:
---------------

Using the centos7 branch you may need to perform the following steps manually to prepare mysql:
~~~
# install mariadb or mysql
sudo yum -y install mariadb-server mariadb
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql_secure_installation
~~~
