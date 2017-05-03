======
ERRATA
======

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

---------------
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

ERRATA modified
