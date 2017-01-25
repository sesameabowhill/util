This is a Chef cookbook that installs a Jenkins Java 8 build system on a target machine (a docker VM).
An up-to-date Chef workstation is required to run it. 

============
INSTALLATION
============

Kill off any other docker instances running. 

From the top directory of this project, run:
~~~
bundle install
kitchen converge
~~~~

The Jenkins web interface should be available at:
~~~
http://172.17.0.2:8080
~~~

=====
GOALS
=====

This project aims to:

1. Be similar to the existing deployed legacy Jenkins in features 
2. Be fully replicable 
3. Use all new, up-to-date tools and modules
4. Be deployable to any kind of server, including cloud
5. Build software using Java 8


All-new versions of the following software will be installed on the target 
(right now a docker centos-6.8 instance):

- Jenkins
- Jenkins Modules
- Java 8
- Maven
- Git

The installed system also uses Oauth validation via Github and does not store system passwords of users. 
If you have a Github Sesacom account, you will be able to access this system.

========
VERSIONS
========

The main branch of this project is designed to install Jenkins on CentOS 6.8 using Docker for development purposes. This should run fine locally on CentOS 7 Chef Workstation or a CentOS 6.x machine. If deployment on CentOS 7 is required, check out the centos7 branch of this project. It currently lags behind the master branch.

=============
PREREQUISITES
=============

Chef scripts should be developed and tested on a dedcated workstation, called a _Chef Workstation_. 
You can run this project locally on a Centos-7.x machine or a Windows machine running VirtualBox using a CentOS-7 image. 
If you already have either type of installation, please clone the project and follow listed steps:

https://github.com/sesacom/sandboxes/tree/master/docker-build

