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

git_client 'default' do
  action :install
  version '1.8.1'
end

# jenkins_plugin supports:
# name 
# version (string/symbol, default: latest)
# source (string)
# install_deps (boolean, default true)
# options (string)

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


# represent each module that has specific version upgrades.
# try each out at the top first
# avoid using 'enable' keyword unless absolutely necessary
# if it fails in the top, move it to the bottom.

#jenkins_plugin 'workflow-aggregator'
#jenkins_plugin 'mysql-auth-plugin' 

#################
# Add Admin Users
#################

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


#########################
# Chef user: experimental
#########################

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


## Jenkins restart before use
## This command is compatible with CenOS7 serviced
jenkins_command 'safe-restart'


