#
# Cookbook Name:: jenkinsjava
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

run_context = node['virtualization']['system']
puts "Run context is: [#{run_context}]"

# update OS
if run_context.match(/docker|vbox/)
   execute "update_os" do
      live_stream true
      command "yum -y update"
   end
end

# install MySQL
mysql_service 'local' do
  version '5.7'
  bind_address '0.0.0.0'
  port '3306'
  data_dir '/data'
  initial_root_password node['passwords']['mysql']
  action [:create, :start]
end

# configure test DBs
template "/var/lib/mysql-files/create_mysql_tables.sql" do
   source 'create_mysql_tables.erb'
   mode '0644'
end

execute 'Create Databases' do
   live_stream true
   command "mysql -h 127.0.0.1 -u root --password=#{node['passwords']['mysql']} < /var/lib/mysql-files/create_mysql_tables.sql"
end

# rebuild Git to very new version. Jenkins and Maven use very new features.
# Git 1.8.0 =< features > Git 1.71
template "/tmp/upgrade_git.sh" do
   source "upgrade_git.erb"
   mode '0744'
end

# TODO: build guards into this
execute 'Upgrade Git' do
   live_stream true
   # git build script - Idempotent but inefficient
   command 'bin/sh /tmp/upgrade_git.sh' 
end

# run java, maven, jenkins installs in sequence
include_recipe 'java' 
include_recipe 'maven' 
include_recipe 'jenkins::master'

# wait 20 seconds for jenkins to boot
execute 'Pause for Jenkins Bootup' do
   live_stream true
   command "sleep 20"
end

# TODO move these to sesame-api project space. They might have to be checked-in.
# copy maven build scripts for sesame-api
template '/var/lib/jenkins/jobs/sesame.properties' do
   source 'sesame.properties'
   mode '0644'
end 

template '/var/lib/jenkins/jobs/settings.xml' do
   source 'settings.xml'
   mode '0644'
end    

# Script not used by Jenkins directly. For manual development and testing in console. 
template '/var/lib/jenkins/jobs/manual_build.sh' do
   source 'manual_build.sh'
   mode '0744'
end    

###
### Other Stuff that is OK to put on before modules are installed
###

# install git global config settings the old-fashioned way
template '/var/lib/jenkins/hudson.plugins.git.GitTool.xml' do
   source 'hudson.plugins.git.GitTool.xml'
   mode '0644'
end

# install Jenkins Global Location information
template '/var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml' do
   source 'jenkins.model.JenkinsLocationConfiguration.xml'
   mode '0644'
end


#################
# Install Plugins
#################

# reads each row of an attribute array and just does the "jenkins_plugin" command with optional 
# version specification and trigger restart commands (both specified in the input row)


installers = node.jenkins['module']['list']

installers.each do |installer|
   nam, ver, trigger_restart = installer
   
   jenkins_plugin nam do
      if ver
         version ver
      end
      if trigger_restart
         notifies :restart, 'service[jenkins]', :immediately
      end
   end
end

# global credentials file
# This must:
# 1. contain a secret which is your raw API key
# 2. must overwrite existing config after modules install
# 3. must be followed by a safe restart
template '/var/lib/jenkins/credentials.xml' do
   source 'credentials.xml'
   mode '0644'
end

# restart Jenkins to ensure all modules finish install
jenkins_command 'safe-restart'

# github plugin config
template '/var/lib/jenkins/github-plugin-configuration.xml' do
   source 'github-plugin-configuration.xml'
   mode '0644'
end

# TODO: not sure we need this
# Ivy configuration 
#template '/var/lib/jenkins/hudson.ivy.IvyBuildTrigger.xml' do
#   source 'hudson.ivy.IvyBuildTrigger.xml'
#   mode '0644'
#end

# MavenModuleSet
template '/var/lib/jenkins/hudson.maven.MavenModuleSet.xml' do 
   source 'hudson.maven.MavenModuleSet.xml'
   mode '0644'
end

# GitSCM
template '/var/lib/jenkins/hudson.plugins.git.GitSCM.xml' do
   source 'hudson.plugins.git.GitSCM.xml'
   mode '0644'
end

# TODO not sure we need this
# Mailer
template '/var/lib/jenkins/hudson.tasks.Mailer.xml' do
   source 'hudson.tasks.Mailer.xml'
   mode '0644'
end

# Extended E-mail
template '/var/lib/jenkins/hudson.plugins.emailext.ExtendedEmailPublisher.xml' do
   source 'hudson.plugins.emailext.ExtendedEmailPublisher.xml'
   mode '0644'
end

# Shell config
template '/var/lib/jenkins/hudson.tasks.Shell.xml' do
   source 'hudson.tasks.Shell.xml'
   mode '0644'
end

# SCMTrigger
template '/var/lib/jenkins/hudson.triggers.SCMTrigger.xml' do
   source 'hudson.triggers.SCMTrigger.xml'
   mode '0644'
end

# Artifactory
template '/var/lib/jenkins/jenkins.model.ArtifactManagerConfiguration.xml' do
   source 'jenkins.model.ArtifactManagerConfiguration.xml'
   mode '0644'
end

# TODO: not sure we need this
# (unknown)
#template '/var/lib/jenkins/org.jenkinsci.plugins.zapper.ZapRunner.xml' do
#   source 'org.jenkinsci.plugins.zapper.ZapRunner.xml'
#   mode '0644'
#end

# Artifacory Builder
template '/var/lib/jenkins/org.jfrog.hudson.ArtifactoryBuilder.xml' do
   source 'org.jfrog.hudson.ArtifactoryBuilder.xml'
   mode '0644'
end


# TODO Slaves in general need to be added and configured
# Slave config
template '/var/lib/jenkins/org.jenkinsci.plugins.slave_setup.SetupConfig.xml' do
   source 'org.jenkinsci.plugins.slave_setup.SetupConfig.xml'
   mode '0644'
end

# Slave status
template '/var/lib/jenkins/slave-status.xml' do
   source 'slave-status.xml'
   mode '0644'
end

# restart Jenkins to ensure all modules finish installing
jenkins_command 'safe-restart'

# wait 20 seconds for jenkins to boot
execute 'Pause for Jenkins Bootup' do
   live_stream true
   command "sleep 20"
end


##
## Create api-dev job
##

# copy over the job definition file 
template '/tmp/config.xml' do
   source 'jobconfig.xml'
   mode '0644'
end

# TODO: replace password and IP address with attributes
# connect into Jenkins JVM to install job just as if we were doing it remotely
if run_context.match(/docker|vbox/)
   execute "add_job" do
      live_stream true
      command 'curl -X POST -H "Content-Type:application/xml" -d @/tmp/config.xml sesameabowhill:7e26fb3e9cd207a5ccc85f399f8502167e6c762d@172.17.0.2:8080/createItem?name=sesame-api'
   end
end

# restart Jenkins to ensure all modules finish install
jenkins_command 'safe-restart'

# wait 20 seconds for jenkins to boot
execute 'Pause for Jenkins Bootup' do
   live_stream true
   command "sleep 20"
end

##
## FINISH GLOBAL CONFIGURATION
##

# global tools configuration
jenkins_script 'Configure Global Tools' do
  command <<-EOH.gsub(/^ {4}/, '')
import jenkins.model.Jenkins

// Set properties in Global Tools Locations entry for local Maven installation
// (idempotent function)
// Maven is a special case and is built-into Jenkins
a=Jenkins.instance.getExtensionList(hudson.tasks.Maven.DescriptorImpl.class)[0];
b=(a.installations as List);

if (b.size == 0)
   {
   b.add(new hudson.tasks.Maven.MavenInstallation("maven-3.3.9", "/usr/local/maven", []));
   a.installations=b;
   a.save();
   }

// Set properties in Global Tools Locations entry for local JDK installation
// (idempotent function)
// JDK is not accessible as an extension, but has its own support classes built-in to Jenkins

hudson_functions = new hudson.Functions();
jdk_descriptor = hudson_functions.getJDKDescriptor();
jdk_installations = jdk_descriptor.getInstallations();

if (jdk_installations.size() == 0)
   {
   this_jdk = new hudson.model.JDK("JDK 8","/usr/lib/jvm/java-1.8.0") as List;
   jdk_descriptor.setInstallations(new hudson.model.JDK("JDK 8","/usr/lib/jvm/java-1.8.0"));
   jdk_descriptor.save();
   }
   EOH
end

##
## Enable OAUTH security, which will lock out further automatic configuration 
## 


jenkins_script 'Setup Oauth Authentication' do
  command <<-EOH.gsub(/^ {4}/, '')
import hudson.security.SecurityRealm
import org.jenkinsci.plugins.GithubSecurityRealm
import jenkins.model.Jenkins
String githubWebUri = 'https://github.com'
String githubApiUri = 'https://api.github.com'
String clientID = '84389e1a195eee676128'
String clientSecret = '4773bd184883cec9b4bd2bf7074d427758054fb4'
String oauthScopes = 'read:org'
SecurityRealm github_realm = new GithubSecurityRealm(githubWebUri,
githubApiUri, clientID, clientSecret, oauthScopes)
//check for equality, no need to modify the runtime if no settings changed
if(!github_realm.equals(Jenkins.instance.getSecurityRealm())) {
    Jenkins.instance.setSecurityRealm(github_realm)
    Jenkins.instance.save()
}
   EOH
end


jenkins_script 'Setup Oauth Access' do
  command <<-EOH.gsub(/^ {4}/, '')
import org.jenkinsci.plugins.GithubAuthorizationStrategy
import hudson.security.AuthorizationStrategy
import jenkins.model.Jenkins

//permissions are ordered similar to web UI
//Admin User Names
String adminUserNames = 'sesameabowhill, thunter, astighall'
//Participant in Organization
String organizationNames = 'sesacom*Development'
//Use Github repository permissions
boolean useRepositoryPermissions = true
//Grant READ permissions to all Authenticated Users
boolean authenticatedUserReadPermission = true
//Grant CREATE Job permissions to all Authenticated Users
boolean authenticatedUserCreateJobPermission = true
//Grant READ permissions for /github-webhook
boolean allowGithubWebHookPermission = false
//Grant READ permissions for /cc.xml
boolean allowCcTrayPermission = false
//Grant READ permissions for Anonymous Users
boolean allowAnonymousReadPermission = false
//Grant ViewStatus permissions for Anonymous Users
boolean allowAnonymousJobStatusPermission = false

AuthorizationStrategy github_authorization = new
GithubAuthorizationStrategy(adminUserNames,
    authenticatedUserReadPermission,
    useRepositoryPermissions,
    authenticatedUserCreateJobPermission,
    organizationNames,
    allowGithubWebHookPermission,
    allowCcTrayPermission,
    allowAnonymousReadPermission,
    allowAnonymousJobStatusPermission)

//check for equality, no need to modify the runtime if no settings changed
if(!github_authorization.equals(Jenkins.instance.getAuthorizationStrategy())) {
    Jenkins.instance.setAuthorizationStrategy(github_authorization)
    Jenkins.instance.save()
}
   EOH
end


