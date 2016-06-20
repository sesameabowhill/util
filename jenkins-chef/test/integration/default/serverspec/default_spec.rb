require 'spec_helper'

set :backend, :exec

describe 'web site' do
   it 'responds on port 8080' do
      expect(port 8080).to be_listening 'tcp'
   end

   it 'returns jenkins in body of HTML' do
      expect(command('curl localhost:8080').stdout).to match /jenkins/
   end
end

describe 'modules are what we tried to install' do
   it 'has no leftover modules' do
      a = `curl -u chef: -X GET 'http://172.17.0.2:8080/pluginManager/api/xml?depth=1&xpath=//shortName|//version&wrapper=plugins'`
      b = (a.split /\<\/?\w*\>/).select { |x| !x.empty? }
      h = Hash[*b]
      puts h.to_a
puts default.jenkins.module.list
      expected_mods = node.default.jenkins.module.list
      expected_mods = expected_mods.map.with_index { |name,idx|  name if idx % 2 }
       
   end

#   it 'has the same version numbers' do
#      expect(command('curl localhost:8080').stdout).to match /jenkins/
#   end
end

