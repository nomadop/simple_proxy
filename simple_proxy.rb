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
	res = RestClient.send(*args)
	status(res.code)
	content_type(res.headers[:content_type])
	res.body
end
