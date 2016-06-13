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
# 2. Install unbroken credentials plugin
# Once the Jenkins instance started, the "credentials" plugin must be added explicity 
# to install missing Groovy libraries. This is a known bug, as the credentials plugin comes packaged
# with Jenkins, just that they forgot to put in all the correct libraries. This plugin requires
# Jenkins to be restarted. Without this step, users cannot be added to the system using the 
# Jenkins cookbook.
#
# 3. Add users
#

# This is most important - centos7 image doesn't come with network enabled
package 'net-tools'

include_recipe 'java' 
include_recipe 'maven' 
include_recipe 'git'
include_recipe 'jenkins::master'
include_recipe 'chef-sugar::default'

#mysql_service 'local' do
#  version '5.7'
#  bind_address '127.0.0.1'
#  port '3306'
#  data_dir '/data'
#  initial_root_password 'Ch4ng3me'
#  action [:create, :start]
#end

# git config --global user.name "sesameabowhill"
# sudo yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel
# sudo yum install  gcc perl-ExtUtils-MakeMaker
# sudo yum remove git
#




git_client 'default' do
  action :install
end

#service "jenkins" do 
#   action [ :start, :enable ]
#end


jenkins_plugin 'ant' do
   :enable
end

jenkins_plugin 'pam-auth' do
   version '1.2'
   :enable
end
#
jenkins_plugin 'junit' do
   version '1.13'
   :enable
#   notifies :restart, 'service[jenkins]', :immediately
end
#
jenkins_plugin 'git' do
   version '2.4.4'
   :enable
   notifies :restart, 'service[jenkins]', :immediately
end

jenkins_plugin 'git-client' do
   :enable
end

jenkins_plugin 'github' do
   :enable
end

jenkins_plugin 'github-api' do
   :enable
end

jenkins_plugin 'versionnumber' do
   :enable
end

jenkins_plugin 'credentials' do
   :enable
   notifies :restart, 'service[jenkins]', :immediately
end

jenkins_plugin 'mailer' do
   :enable
   notifies :restart, 'service[jenkins]', :immediately
end

jenkins_plugin 'email-ext' do
   :enable
end

jenkins_plugin 'matrix-auth' do
   :enable
end

jenkins_plugin 'matrix-project' do
   version '1.7'
   :enable
end

jenkins_plugin 'ssh-credentials' do
   version '1.12'
   :enable
end

jenkins_plugin 'plain-credentials' do
   version '1.2'
   :enable
end

jenkins_plugin 'ssh-agent' do
   :enable
   notifies :restart, 'service[jenkins]', :immediately
end

jenkins_plugin 'workflow-step-api' do
   version '2.1'
   :enable
end

jenkins_plugin 'external-monitor-job' do
   :enable
end

jenkins_plugin 'maven-plugin' do 
   version '2.13'
   :enable 
   notifies :restart, 'service[jenkins]', :immediately
end

jenkins_plugin 'nodenamecolumn' do
   :enable
end

jenkins_plugin 'jobtype-column' do
   :enable
end

jenkins_plugin 'greenballs' do
   :enable
end

jenkins_plugin 'view-job-filters' do
   :enable
end

jenkins_plugin 'dashboard-view' do
   :enable
end

jenkins_plugin 'javadoc' do
   version '1.3'
   :enable
end

jenkins_plugin 'instant-messaging' do
   :enable
end

jenkins_plugin 'jabber' do
   :enable
end

jenkins_plugin 'artifactdeployer' do
   :enable
end

jenkins_plugin 'artifactory' do
   :enable
end

jenkins_plugin 'copy-to-slave' do
   :enable
end

jenkins_plugin 'slave-setup' do
   :enable
end

jenkins_plugin 'ssh-slaves' do
   :enable
end

jenkins_plugin 'slave-status' do
   :enable
end

jenkins_plugin 'slack' do
   :enable
end

jenkins_plugin 'performance' do
   :enable
end
 
jenkins_plugin 'cobertura' do
   :enable
end

jenkins_plugin 'envfile' do
   :enable
end

jenkins_plugin 'file-leak-detector' do
   :enable
end

jenkins_plugin 'scm-api' do
   version '1.2'
   :enable
end

jenkins_plugin 'script-security' do
   version '1.19'
   :enable
end

jenkins_plugin 'token-macro' do
   version '1.12.1'
   :enable
end

#jenkins_plugin 'mysql-auth-plugin' do
#   :enable
#end

###############
# Admin Users
###############

jenkins_user 'abowhill' do
   full_name    'Allan Bowhill'
   email        'abowhill@sesamecommunications.com'
   public_keys  node.default.jenkins.user.abowhill.public_key
   password    'sesame3'
end

jenkins_user 'astighall' do
   full_name    'Annalise Stighall'
   email        'astighall@sesamecommunications.com'
   public_keys  node.default.jenkins.user.abowhill.public_key
   password    'sesame2'
end

jenkins_user 'thunter' do
   full_name    'Teo Hunter'
   email        'thunter@sesamecommunications.com'
   public_keys  node.default.jenkins.user.abowhill.public_key
   password    'sesame1'
end


###########################
# Chef user : experimental
###########################

unless node['jenkins']['executor']['private_key']
require 'net/ssh'
   key = OpenSSL::PKey::RSA.new(4096)
   node.set['jenkins-chef']['user']['private_key'] = key.to_pem
   node.set['jenkins-chef']['user']['public_key'] =
   "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
end

# Creates the 'chef' Jenkins user and assciates the public key
# Needs anonymous auth to create a user, to then use this users there after.
#  See Caviots: https://github.com/opscode-cookbooks/jenkins#caveats

jenkins_user 'chef' do
  full_name   'Chef Client'
  public_keys [ node['jenkins-chef']['user']['public_key'] ]
end

# Set the private key on the Jenkins executor, must be done only after the user
#  has been created, otherwise API will require authentication and not be able
#  to create the user.
ruby_block 'set private key' do
   block do
     node.set['jenkins']['executor']['private_key'] =
     node['jenkins-chef']['user']['private_key']
   end
end

# If auth scheme is set, include recipe with that implementation.
if node['jenkins-chef']['auth']
   include_recipe "jenkins-chef-dsl::_auth-#{node['jenkins-chef']['auth']}"
end



##########################
# Commit security changes
##########################


# Basic Jenkins authentication policy activation
# Must appear near end of recipt or it will not be allowed to be created
# by anonymous user. This script is run once in this blockr. NOT IDEMPONTENT
jenkins_script 'setup authentication' do
  command <<-EOH.gsub(/^ {4}/, '')
    import jenkins.model.*
    import hudson.security.*
    import org.jenkinsci.plugins.*

    def instance = Jenkins.getInstance()

    def realm = new HudsonPrivateSecurityRealm(false)
    instance.setSecurityRealm(realm)

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    instance.setAuthorizationStrategy(strategy)

    instance.save()
  EOH
end



# Using encrypted data bags and chef-sugar
#private_key = encrypted_data_bag_item('jenkins', 'keys')['private_key']
#node.run_state[:jenkins_private_key] = private_key




##########################################################
#jenkins_keys = encrypted_data_bag_item('jenkins', 'keys')

#require 'openssl'
#require 'net/ssh'

#key = OpenSSL::PKey::RSA.new(jenkins_keys['private_key'])
#private_key = key.to_pem
#public_key = "#{key.ssh_type} #{[key.to_blob].pack('m0')}"

#Create the Jenkins user with the public key
#jenkins_user 'chef' do
#   public_keys [public_key]
#end

# Set the private key on the Jenkins executor
#node.run_state[:jenkins_private_key] = private_key
########################################################


#service "jenkins" do 
#   action [ :restart ]
#end
jenkins_command 'safe-restart'
