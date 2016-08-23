require 'chefspec'
require 'chefspec/berkshelf'
require 'attributes/default.rb'
at_exit { ChefSpec::Coverage.report! } 

