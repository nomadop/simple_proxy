require 'rubygems'
require 'sinatra'
require 'rest-client'
require 'redis'
require 'json'

ProxyRedis = Redis.new(host: 'localhost', port: 6379, db: 5)

post '/' do
	begin
		id = Time.now.to_f.to_s
		ProxyRedis.synchronize do
			queue = JSON.parse(ProxyRedis.get('queue'))
			queue << params.merge(id: id)
			ProxyRedis.set('queue', queue.to_json)
		end
		res = nil
		while res == nil
			sleep 1
			res = ProxyRedis.get(id)
		end
		ProxyRedis.del(id)
		res
	rescue Exception => e
		headers({system_error: 'true'})
		{error: e.inspect, backtrace: e.backtrace}.to_json
	end
end
