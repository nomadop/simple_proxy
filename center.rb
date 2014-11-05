require 'rubygems'
require 'sinatra'
require 'rest-client'
require 'json'
require 'yaml'
require 'redis'

require './request.rb'
require './response.rb'

class Connection
	attr_accessor :socket, :busy, :host, :port

	RedisServer = Redis.new(host: 'localhost', port: 6379, db: 15)
	ConnList = []
	ConnMutex = Mutex.new
	
	def initialize host, port
		@host = host
		@port = port
		# @socket = nil
		@socket = TCPSocket.new host, port
	end

	def connect
		# @socket = TCPSocket.new host, port
	end

	def disconnect
		# @socket.close
		@busy = false
	end

	def recv
		data = ""
    loop do
      begin
        msg = socket.read_nonblock(100000)
        # p msg
        data += msg if msg
        break if data.end_with?('EOF')
      rescue Errno::EAGAIN => e
        sleep 0.1
      rescue EOFError => e
        data = ""
        break
      end
    end
    data[0...-3]
		# socket.read
	end

	def send msg
		# socket.send(msg + 'EOF', 0)
		socket.write(msg)
		socket.write('EOF')
		# socket.write(msg)
		# socket.close_write
	end

	def self.new_conn
		if ConnList.size <= 10
			# server = nil
			# RedisServer.synchronize do
			  servers = JSON.parse(RedisServer.get('servers') || "{}")
			  server = servers.sort_by{|k ,v| v}.first[0]
			#   servers[server] += 1
			#   RedisServer.set('servers', servers.to_json)
			# end
			host, port = server.split(':')
			conn = Connection.new(host, port)
			ConnList << conn
			conn
		else
			sleep 0.1
			nil
		end
	end

	def self.get_conn
		conn = nil
		while conn == nil
			ConnMutex.synchronize do
				conn = ConnList.select{|c| c.busy == false}.shuffle.first
				conn.busy = true if conn
			end
			conn = new_conn unless conn
		end
		conn.connect
		conn
	end
end

post '/' do
	begin
		st = Time.now
		id = st.to_f.to_s
		conn = Connection.get_conn
		req = Request.new(params[:method], params[:url], params[:data])
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
	ensure
		conn.disconnect if conn
	end
end

@@counter = 0

get '/test' do
	@@counter += 1
	p @@counter
	@@counter -= 1
	'test'
end
