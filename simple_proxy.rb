require 'rubygems'
require 'sinatra'
require 'rest-client'

post '/' do
	url = params[:url]
	method = params[:method] || :get
	data = params[:data]
	data = JSON.parse(data) if data.is_a?(String)
	args = [method, url]
	args << data if data
	puts args
	res = RestClient.send(*args)
	status(res.code)
	headers(res.headers.inject({}) do |r, kvp|
		k, v = kvp
		k = k.to_s.split('_').map(&:capitalize).join('-')
		r[k] = v
		r
	end)
	body(res.body)
end
