require 'bunny'
require 'base64'
require 'pry'
require 'json'

class MessageQueue
  def initialize(connection, q_name)
		@ch = connection.create_channel
		@queue = @ch.queue(q_name, :durable => true, exclusive: false, :auto_delete => false)
    # Messaging.connection =  Bunny.new.tap do |conn|
    #   conn.start
    # end

    # Messaging.channel = Messaging.connection.create_channel
    # Messaging.exchange = Messaging.connection.topic('ihids.messages')
  end

  # def self.connection
  #   @connection  ||= Bunny.new.tap do |c|
  #     c.start
  #   end
  # end
  def publish(payload)
	  # if payload.has_key('image')?
			# 	 image = payload['image']
			# 	 payload[image] =  Base64.encode64(image)
	  # end
	  json = payload.to_json
	  # msg = Base64.encode64(data)

	  @ch.default_exchange.publish(json, routing_key: @queue.name, :persistent => true, :auto_delete => false,
	                               :durable => true, :exclusive => false)
  end

  # def subscribe
  #   subscribe(:manual_ack => true,:block => true)
  # end

  def queue
	  @queue
  end

  def ch
    @ch
  end

  def close_channel
	  @ch.close
  end

  def ack(msg)
	  @ch.ack(msg)
  end

  def nack(msg)
	  @ch.nack(msg)
  end
  # def self.topic_exchange
  #   @topic_exchange ||= self.channel.topic('ihids')
  # end
  def stop
	  @ch.close
	  @conn.close
  end


end
