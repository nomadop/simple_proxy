require 'rubygems'
# require 'faraday'
require 'rest-client'
require 'redis'
require 'json'
require 'yaml'

ProxyRedis = Redis.new(host: 'localhost', port: 6379, db: 5)

class Worker
	attr_accessor :current_id

	def initialize
		@current_id = nil
	end

	def run
		while true
			sleep 1
			params = nil
			ProxyRedis.synchronize do
				queue = JSON.parse(ProxyRedis.get('queue'))
				params = queue.pop
				ProxyRedis.set('queue', queue.to_json)
			end
			if params
				p params
				@current_id = params['id']
				url = params['url']
				method = params['method'] || :get
				data = params['data']
				# args = [method, url]
				# args << data if data
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
				# res = RestClient.send(*args)
				ProxyRedis.set(@current_id, res.to_yaml)
				p "respond to #{@current_id}"
			end
		end
	rescue Exception => e
		File.open('error', 'a+') do |io|
			io.puts(e.inspect)
			e.backtrace.each do |m|
				io.puts("    #{m}")
			end
			io.puts "\n"
		end
		ProxyRedis.set(@current_id, {error: e.inspect, backtrace: e.backtrace}.to_json) if @current_id
		run
	end
end


tasks = []
ARGV.first.to_i.times do
	tasks << Thread.new {
		w = Worker.new
		w.run
	}
end
tasks.each {|t| t.join}
