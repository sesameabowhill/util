=====
ABOUT
=====

This project is designed to install a Jenkins system that will ultimately replace the existing one at http://jenkins.sesamecom.com.

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
sudo yum makecache fast
sudo yum -y update
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
wget https://packages.chef.io/stable/el/6/chefdk-0.19.6-1.el6.x86_64.rpm
rpm -ivh chefdk-0.19.6-1.el6.x86_64.rpm

# run this, but also add it afterwards to .bash-profile for proper future build environment settings
eval "$(chef shell-init bash)"

# verify the chef build environment settings are correct (each should return reasonable values)
which ruby
/opt/chefdk/embedded/bin/ruby --version
chef-client --version
~~~

Install development tools group (required for Bundler to run in newer
installations)

~~~
sudo yum grouplist
sudo yum groupinstall "Development Tools" 
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
ls -l /sys/class/misc/device-mapper # should show files. If not, install this
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

Converge this cookbook to deploy Jenkins into a CentOS 6.8 VM:

~~~
cd SESACOM/utils/jenkins-chef
kitchen converge
~~~

The installation and configuration takes about 10-30 minutes, you should be able to access the completed installation at ```http://172.17.0.2:8080```.  Your login will be authenticated through github, so authenticate with your Github username and password.


- You can dispose of the whole installation by issuing a ```kitchen destroy```. 
- You can login to the virtual machine running Jenkins using ```kitchen login``` or ssh as kitchen to the machine address with the password ```kitchen```.
- You can test the installation by building the inluded mock job of the sesame-api project. Click 'sesame-api' then 'build now'. This is a special demo/test branch.
