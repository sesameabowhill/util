#
# Cookbook Name:: jenkinsjava
# Spec:: default

require 'chefspec'
require 'spec_helper'

describe 'jenkinsjava::default' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs jenkins' do
      expect(chef_run).to install_package('java-1.8.0-openjdk.x86_64')
      expect(chef_run).to install_package('jenkins')
    end

    it 'creates a service' do
      expect(chef_run).to start_service('jenkins')
      expect(chef_run).to enable_service('jenkins')
    end
end

