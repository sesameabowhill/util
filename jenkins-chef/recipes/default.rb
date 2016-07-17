#
# Cookbook Name:: jenkinsjava
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# NOTES:
#
# 1. Dispose of SetupWizard 
# The Jenkins SetupWizard is a new thing requiring manual steps. It is disabled in 
# this project's attribute file. Disabling the SetupWizard also disables security during 
# installation for a short period. The attribute to disable the SetupWizard is boolean 
# and the implemented as a Java property option passed in to the JVM command line. 
#
# node.set.jenkins.master['jvm_options'] = '-Djenkins.install.runSetupWizard=false'
# 

run_context = node['virtualization']['system']
puts "Run context is: [#{run_context}]"


if run_context.match(/docker|vbox/)
   execute "update_os" do
      live_stream true
      command "yum -y update"
   end
end

mysql_service 'local' do
  version '5.7'
  bind_address '0.0.0.0'
  port '3306'
  data_dir '/data'
  initial_root_password node['passwords']['mysql']
  action [:create, :start]
end

template "/var/lib/mysql-files/create_mysql_tables.sql" do
   source 'create_mysql_tables.erb'
   mode '0644'
end

execute 'Create Databases' do
   live_stream true
   command "mysql -h 127.0.0.1 -u root --password=#{node['passwords']['mysql']} < /var/lib/mysql-files/create_mysql_tables.sql"
end

template "/tmp/upgrade_git.sh" do
   source "upgrade_git.erb"
   mode '0744'
end

execute 'Upgrade Git' do
   live_stream true
   command 'bin/sh /tmp/upgrade_git.sh'
end

include_recipe 'java' 
include_recipe 'maven' 
include_recipe 'jenkins::master'

# wait 20 seconds for jenkins to boot
execute 'Pause for Jenkins Bootup' do
   live_stream true
   command "sleep 20"
end

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


# install git global config settings the old-fashioned way
template '/var/lib/jenkins/hudson.plugins.git.GitTool.xml' do
   source 'hudson.plugins.git.GitTool.xml'
   mode '0644'
end


#################
# Install Plugins
#################

# reads each row of an attribute array and just does the "jenkins_plugin" command with optional 
# version specification and trigger restart commands (both specified in the input row)

installers = node.default.jenkins.module.list

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

# restart Jenkins to ensure all modules finish install
jenkins_command 'safe-restart'


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
// JDK is not accessible as an extension, but has its own classes built-in
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
