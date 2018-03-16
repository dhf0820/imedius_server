require 'bunny'
require 'base64'
require 'pry'

class ImediusQueue

	def initialize(connection)
		@ch   = connection.create_channel
		@queue = @ch.queue("ids.efax")

		#@key = "ihids.archive.#{mode}"
	end

	def publish(data)
		puts "   Storing #{data}"

		json = data.to_json

		# msg = Base64.encode64(data)

		@ch.default_exchange.publish(json, routing_key: @queue.name, :persistent => true, :auto_delete => false,
		                             :durable => true, :exclusive => false)


	end

	def queue
		@queue
	end

	def ch
		@ch
	end

	def close
		@ch.close
	end

	def ack(msg)
		@ch.ack(msg)
	end
end