class Response
	attr_accessor :status, :content_type, :body

	def initialize res
		@status = res.code.to_i
		@content_type = res.header['content-type']
		@body = res.body
	end

end
