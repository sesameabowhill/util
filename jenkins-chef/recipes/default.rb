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


package 'net-tools'

include_recipe 'java' 
include_recipe 'maven' 
include_recipe 'git'
include_recipe 'jenkins::master'
#include_recipe 'chef-sugar::default'

mysql_service 'local' do
  version '5.7'
  bind_address '0.0.0.0'
  port '3306'
  data_dir '/data'
  initial_root_password 'sesame'
  action [:create, :start]
end

template "/var/lib/mysql-files/create_mysql_tables.sql" do
   source 'create_mysql_tables.erb'
   mode '0644'
end

execute 'create databases' do
   command "mysql -h 127.0.0.1 -u root --password='sesame' < /var/lib/mysql-files/create_mysql_tables.sql"
end

git_client 'default' do
  action :install
end

template '/var/lib/jenkins/jobs/sesame.properties' do
   source 'sesame.properties'
   mode '0644'
end    

template '/var/lib/jenkins/jobs/settings.xml' do
   source 'settings.xml'
   mode '0644'
end    

# This command reads all installed modules, gets their version numbers and places them into 
# a dictionary -- for testing 
#curl -uabowhill:sesame3 -X GET 'http://172.17.0.2:8080/pluginManager/api/xml?depth=1&xpath=//shortName|//version&wrapper=plugins' | ruby -ne 'list = $_.split /<shortName>|<version>/; list.map! { |item| /(\w|\.|-|_)+/.match(item) }; list.shift; h = Hash[*list]; puts h.to_a' | less



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

jenkins_command 'safe-restart'

jenkins_script 'setup authentication' do
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


jenkins_script 'setup access' do
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

