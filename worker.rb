require 'rubygems'
require 'rest-client'
require 'redis'
require 'json'
require 'yaml'

require './request.rb'
require './response.rb'

class Worker
	attr_accessor :socket, :thread

	def initialize socket
		@socket = socket
		@thread = Thread.new { run }
	end

	def run
		while true
			sleep 0.1
			begin
				msg = socket.recv(1000000000)
				loop do
					begin
						rest = socket.recv_nonblock(1000000000)
						msg += rest if rest
					rescue Exception => e
						break
					end
				end
				request = YAML.load(msg)
				st = Time.now
				p request
				@current_id = request.id
				url = request.url
				method = request.method || :get
				data = request.data || {}
				uri = URI(url)
				uri.singleton_class.class_eval do
					def empty?
						false
					end
				end
				if method.to_s == 'get'
					req = Net::HTTP::Get.new(uri)
				else
					req = Net::HTTP::Post.new(uri)
					req.set_form_data(data)
				end
				res = Net::HTTP.start(uri.host) do |http|
					http.read_timeout = 5
					http.open_timeout = 2
					http.request(req)
				end
				response = Response.new(res)
				socket.send(response.to_yaml, 0)
				p "respond to #{@current_id} (#{((Time.now - st) * 1000).round(0)}ms)"
			rescue Exception => e
				File.open('error', 'a+') do |io|
					io.puts(e.inspect)
					e.backtrace.each do |m|
						io.puts("    #{m}")
					end
					io.puts "\n"
				end
				socket.send(e.to_yaml, 0)
			end
		end
	end
end

CenterHost = File.read('centerhost').gsub(/\n/, '')
RedisServer = Redis.new(host: CenterHost, port: 6379, db: 15)
SocketHost = ARGV[0]
SocketPort = ARGV[1].to_i
SocketServer = TCPServer.new SocketPort

RedisServer.synchronize do
	servers = JSON.parse(RedisServer.get('servers') || "{}")
	servers["#{SocketHost}:#{SocketPort}"] = 0
	RedisServer.set('servers', servers.to_json)
end

Listener = Thread.new do
	loop do
		client = SocketServer.accept
		p "new client connected: #{client}"
		w = Worker.new(client)
	end
end

begin
	Listener.join
ensure
	RedisServer.synchronize do
		servers = JSON.parse(RedisServer.get('servers'))
		servers.delete("#{SocketHost}:#{SocketPort}")
		RedisServer.set('servers', servers.to_json)
	end
end
