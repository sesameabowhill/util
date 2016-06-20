require 'chefspec'
require 'chefspec/berkshelf'
requiire 'attributes/default.rb'
at_exit { ChefSpec::Coverage.report! } 

