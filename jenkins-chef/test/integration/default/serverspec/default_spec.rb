require 'spec_helper'

set :backend, :exec

describe 'web site' do
   it 'responds on port 80' do
      expect(port 8080).to be_listening 'tcp'
   end

   it 'returns jenkins in body of HTML' do
      expect(command('curl localhost:8080').stdout).to match /jenkins/
   end
end

