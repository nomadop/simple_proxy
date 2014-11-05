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
    p "new client connected: #{socket}"
    RedisServer.synchronize do
      servers = JSON.parse(RedisServer.get('servers') || "{}")
      servers["#{SocketHost}:#{SocketPort}"] += 1
      RedisServer.set('servers', servers.to_json)
    end
    @thread = Thread.new { run }
  end

  def recv
    data = ""
    loop do
      begin
        msg = socket.read_nonblock(100000)
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
  
  def close
  	socket.close
  end

  def run
    loop do
      begin
        request = YAML.load(recv)
        break unless request
        st = Time.now
        p request
        url = request.url
        method = request.method || :get
        data = request.data || {}
        data = JSON.parse(data) if data.is_a?(String)
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
        send(response.to_yaml)
        p "respond to #{@current_id} (#{((Time.now - st) * 1000).round(0)}ms)"
      rescue Exception => e
        File.open('error', 'a+') do |io|
          io.puts(e.inspect)
          e.backtrace.each do |m|
            io.puts("    #{m}")
          end
          io.puts "\n"
        end
        send(e.to_yaml)
      end
    end
    p "client disconnected: #{socket}"
    RedisServer.synchronize do
      servers = JSON.parse(RedisServer.get('servers') || "{}")
      servers["#{SocketHost}:#{SocketPort}"] -= 1
      RedisServer.set('servers', servers.to_json)
    end
  end
end

CenterHost = File.read('centerhost').gsub(/\n/, '')
RedisServer = Redis.new(host: CenterHost, port: 6379, db: 15)
SocketHost, SocketPort = ARGV
SocketServer = TCPServer.new SocketPort.to_i

RedisServer.synchronize do
  servers = JSON.parse(RedisServer.get('servers') || "{}")
  servers["#{SocketHost}:#{SocketPort}"] = 0
  RedisServer.set('servers', servers.to_json)
end

Listener = Thread.new do
  loop do
    client = SocketServer.accept
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
