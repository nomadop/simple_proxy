require 'rubygems'
require 'daemons'

Daemons.run('./worker.rb')
