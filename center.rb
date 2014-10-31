require 'rubygems'
require 'sinatra'
require 'rest-client'
require 'json'
require 'yaml'
require 'redis'

require './request.rb'
require './response.rb'

class Connection
	attr_accessor :socket

	RedisServer = Redis.new(host: 'localhost', port: 6379, db: 15)
	@@conn = nil
	
	def initialize host, port
		@socket = TCPSocket.new host, port
		raise TypeError unless @socket.is_a?(TCPSocket)
	end

	def recv
		msg = socket.recv(1000000000)
		loop do
			begin
				rest = socket.recv_nonblock(1000000000)
				msg += rest if rest
			rescue Exception => e
				break
			end
		end
		msg
	end

	def send msg
		socket.send(msg, 0)
	end

	def self.init_conn
		server = nil
		RedisServer.synchronize do
			servers = JSON.parse(RedisServer.get('servers'))
			server = servers.sort_by{|k ,v| v}.first[0]
			servers[server] += 1
			RedisServer.set('servers', servers.to_json)
		end
		host, port = server.split(':')
		@@conn = Connection.new(host, port)
	end

	def self.get_conn
		@@conn
	end
end

Connection.init_conn

post '/' do
	begin
		st = Time.now
		id = st.to_f.to_s
		conn = Connection.get_conn
		req = Request.new(id, params[:method], params[:url], params[:data])
		conn.send(req.to_yaml)
		msg = conn.recv
		# p msg
		res = YAML.load(msg)
		status(res.status)
		content_type(res.content_type)
		body(res.body)
	rescue Exception => e
		headers({system_error: 'true'})
		{error: e.inspect, backtrace: e.backtrace}.to_json
	end
end
