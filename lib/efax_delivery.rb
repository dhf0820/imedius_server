$:.unshift(File.dirname(__FILE__)) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))


puts "in efax_server::efax_delivery.rb"
require 'pry'
require 'bunny'
require 'active_record'
require 'pg'

require 'efax'
# need to actually include everything in lib automatically

require_relative './cli'

require_relative './queue_processor'
require_relative './db_connection'
require_relative './message_queue'
require_relative '../models/archived_image'
require_relative '../models/clinical_document'
require_relative '../models/delivery_class'
require_relative '../models/delivery_device'
require_relative '../models/delivery_history'
require_relative '../models/delivery_profile'
require_relative '../models/delivery_queue'
require_relative '../models/delivery_request'
require_relative '../models/document_class'
require_relative '../models/document_type'
require_relative '../models/document_version'
require_relative '../models/patient'
require_relative '../models/physician'
require_relative '../models/practice'
require_relative '../models/delivery_job'



class EfaxDelivery
  attr_reader :service

  def initialize(mode, service_name, base_path)
    @mode = mode
    @base_path = base_path
    @service_name = service_name
    puts "Service Name = #{@service_name}"
    $db_connection = DbConnection.new
    #@working_path = "#{@base_path}/efax_processor/#{@mode}"   #/p_#{Process.pid.to_s}/"
    @service =  DeliveryClass.where(:name => @service_name).first
    if service.nil?
      abort "DeliveryClass name of #{@service_name} does not exist"
    end
    puts "Serviving Delivery Class #{@service.name}"
    #FileUtils.mkdir_p @working_path

    rabbit = ENV['IDSAMQP']
    if rabbit.nil? || rabbit.blank?  # use local RabbitMq Server
      rabbit = nil
    end

    connection = Bunny.new(rabbit)
    connection.start
    $deliver_que    = MessageQueue.new(connection, @service.command)



    EFax::Request.account_id = '7029757933'
    EFax::Request.user = 'vertisof'
    EFax::Request.password = 'vertisof'



  end

  def mode
    @module
  end

  # def xchange
  #   @xchange
  # end
  #
  # def channel
  #   @channel
  # end
  #
  def queue
    @queue
  end

  def queue=(val)
    @queue = val
  end

  def service
    @service
  end

  # def stop
  #   @channel.close
  #   @conn.close
  # end


end

