require 'rubygems'
require 'sinatra'
require 'rest-client'
# require 'redis'
# require 'json'

# class Connection
# 	@@count = 0
# 	@@redis = Redis.new(host: '203.195.155.91', port: 6380, db: 7)
# 	@@localhost = File.read('localhost').gsub(/\n/, '')

# 	def self.connect
# 		@@count += 1
# 		update
# 	end

# 	def self.disconnect
# 		@@count -= 1
# 		update
# 	end

# 	def self.update
# 		@@redis.synchronize do
# 			data = JSON.parse(@@redis.get('servers'))
# 			data[@@localhost] = {connection: @@count}
# 			@@redis.set('servers', data.to_json)
# 		end
# 	rescue Exception => e
# 		p 'Failed to connect redis server.'
# 		p e
# 		p e.backtrace
# 	end

# 	update
# end

post '/' do
	begin
		# Connection.connect
		url = params[:url]
		method = params[:method] || :get
		data = params[:data]
		data = JSON.parse(data) if data.is_a?(String)
		args = [method, url]
		args << data if data
		res = RestClient.send(*args)
		status(res.code)
		content_type(res.headers[:content_type])
		# Connection.disconnect
		res.body
	rescue Exception => e
		headers({system_error: 'true'})
		e.inspect
	end
end
