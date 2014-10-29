# require './simple_proxy.rb' 
require './center.rb'

root_dir = File.dirname(__FILE__) 

set :environment, ENV['RACK_ENV'].to_sym 
set :root,        root_dir 
# set :app_file,    File.join(root_dir, 'simple_proxy.rb') 
set :app_file,    File.join(root_dir, 'center.rb')
set :environment, :production
disable :run 

run Sinatra::Application 
