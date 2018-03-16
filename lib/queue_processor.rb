require 'bunny'
require 'base64'
require 'pry'
require 'json'
# require 'rest-client'
# require 'pdfkit'


class QueueProcessor
  #
  def initialize(fax)
    @fax = fax
		@service = fax.service
    #puts "Service: #{@service.inspect}"
    rabbit = ENV['IDSAMQP']
    if rabbit.nil? || rabbit.blank?  # use local RabbitMq Server
	    rabbit = nil
    end

    connection = Bunny.new(rabbit)
    connection.start
     @req_que = MessageQueue.new(connection, @fax.service.command)
		@queue = @req_que.queue

    # rabbit = ENV['IDSAMQP']
    # if rabbit.nil? || rabbit.blank?  # use local RabbitMq Server
	   #  rabbit = nil
    # end
    # connection = Bunny.new(rabbit)
    # connection.start
    # @deliver_que    = MessageQueue.new(connection,'ids.efax')
  end


  def process_queue()

    begin
	    puts "[x]  Waiting for job on #{@service.name}"
	    @queue.subscribe(:manual_ack => true,:block => true) do |delivery_info, properties, body|
			#@fax.queue.subscribe do |delivery_info, properties, body|
				puts "Received #{body}"
		    @queue_data = JSON.parse(body)
		    puts "@queue_data: #{@queue_data}"
				@task = @queue_data['task']
				job_id = @queue_data['job_id']
				@job_type = @queue_data['type']

				if @task == 'send'
					if @queue_data['type'] == 'direct'
						puts " Processing direct job #{job_id}"
						results = deliver_direct(job_id)
					else
						puts " Processing send job: #{job_id}"
		        results = deliver(job_id)
					end

				elsif @task == 'status'
					puts "id = #{job_id.class}"
					check_status
				else
					puts "#{@task } is an invalid option use 'send' or 'status'"
				end


		    @req_que.ack(delivery_info.delivery_tag)
				check_status
		    puts "[x]  Waiting for job on #{@service.name}"
	    end
    rescue Interrupt => ex
	    @req_que.close
    rescue Exception => ex
	    puts "   ProcessQueue exception #{ex.inspect}"
	    #binding.pry
    end

  end




  def deliver(job_id)
			job = DeliveryJob.find job_id
			device = DeliveryDevice.find job.device_id
			requests = DeliveryRequest.where(:job_id => job_id)

			requests.each do |req|
				#puts "Request: #{req.inspect}"
				req.status = 'Processing'
				req.status_time = Time.now
				req.save
				doc = ClinicalDocument.find req.doc_id
				phy = Physician.find req.phy_id
				#prac = Practice.find phy.prac_id
				doc_type = DocumentType.find doc.type_id
				image = doc.archived_image.image

				send_state=  Fax::OutBoundRequest.post(phy.name, "VertiSoft", device.command, doc_type.description, image, {transmissionid: job_id })
				if send_state.status_code == 1
					req.status  = "Sending"
					req.status_time = Time.now
					req.last_attempt = Time.now
					req.remote_id = send_state.doc_id

					req.save
					job.remote_id = send_state.doc_id
					job.save
					puts "QueueId: #{send_state.doc_id}"
				# elsif send_state.outcome == 'Answer detected, probable human'
				# 	req.status = "Human"
				# 	req.status_time = Time.now
				# 	req.
				# 	device.status_reason = send_state.outcome
				# 	device.status_time = Time.now
				# 	device.status = "Human"
				# 	device.save
				else
					req.status = 'Bad Submit'
					req.status_time = Time.now
					req.last_attempt = Time.now
					req.next_attempt = Time.now + req.delay_time * 60
					req.remote_id = nil
					req.num_tries+=1
					req.save
					job.delete
				end
			end
  end

  def deliver_direct(job_id)
	  job = DeliveryJob.find job_id
	  if @queue_data['image'].nil?
			image = Base64.decode64(job.image)
	  else
			image = Base64.decode64(@queue_data['image'])
	  end
	  if job.device_id.nil?
			fax_number = @queue_data['command']
	  else
			device = DeliveryDevice.find job.device_id
			fax_number = device.command
	  end

	  send_state = Fax::OutBoundRequest.post('Verification', "VertiSoft", fax_number, 'FAX VERIFICATION', image, {transmissionid: job_id })

	  if send_state.status_code == 1
		  job.remote_id = send_state.doc_id
		  job.start_time = Time.now
		  job.save
		  puts "QueueId: #{send_state.doc_id}"
	  else
			puts "Bad Submit"
			puts "   Status Code #{send_state.status_code}"

	  end

  end

	def check_status
		jobs = DeliveryJob.where(:class_id => @service.id).where.not(:remote_id=> nil)
		return if jobs.count == 0
		jobs.each do |job|
			status = Fax::OutboundStatus.post(job.remote_id)
			puts "Sataus for #{job.remote_id}: #{status.inspect}"

			if job.job_type == 'direct'
				if status.status_code == 4
					successful_direct(status, job)
				elsif status.status_code == 3
					# if status.last_time == ''
					# 	puts "  Job #{job.id} is waiting for first attempt to send."
					# else
					# 	puts " Job #{job.id} status #{status.outcome}. Next retry: #{status.nextdate} #{status.nexttime}"
					# end
				elsif status.status_code == 5
					if status.outcome == 'Answer detected, probable human'
						human_direct(status,job)
					else
						failed_direct(status, job)
					end
				else
					puts "Unknown direct status: #{status.inspect}"
				end
			else
				if status.status_code == 4
					successful_send(status, job)
				elsif status.status_code == 3
					# if status.last_time == ''
					# 	puts "  Job #{job.id} is waiting for first attempt to send."
					# else
					# 	puts " Job #{job.id} status #{status.ooutcome}. Next retry: #{status.nextdate} #{status.nexttime}"
					# end

				elsif status.status.code == 5
					if status.outcome == 'Answer detected, probable human'
						human(status,job)
					else
						failed(status, job)
					end
				else
					puts "Unknown status: #{status.inspect}"
				end
			end

		end
	end

	def successful_send(status, job)
		puts "Successfully sent job #{job.id} " # to #{status.remote_csid}"
		reqs = DeliveryRequest.where(:job_id => job.id )
		reqs.each do |req|
			puts "Deleting request #{req.inspect}"
			reqs = DeliveryRequest.where(:job_id => job.id )

			#TODO add delivery of request to history
			req.delete
		end
		job.delete
	end

	def human(status, job)
		device = DeliveryDevice.find job.device_id
		device.status= 'Hold'
		device.status_time = Time.now
		device.status_reason = status.outcome
		device.save
		reqs = DeliveryRequest.where(:job_id => job.id )
		reqs.each do |req|
			req.status = 'Hold'
			req.status_time = Time.now
			req.status_reason = status.outcome
			req.save
		end
	end

	def failed(status, job)
		reqs = DeliveryRequest.where(:job_id => job.id )
		reqs.each do |req|
			req.num_tries += 5  # server tried 5 times
			if req.num_tries >= max_tries
				send_to_night(job)
			else
				req.status = 'Failed'
				req.status_time = Time.now
				req.status_reason = status.outcome
				req.last_attempt = Time.now
				req.next_attempt = Time.now + req.delay_time * 60
				req.job_id = nil
				req.remote_id = nil
				req.save
				#TODO Add request to history
			end
		end
		job.delete
	end

  def successful_direct(status, job)
	  puts "Successfully direct job #{job.id} " # to #{status.remote_csid}"
	  job.status = status.outcome
	  job.remote_id = nil
	  job.status_time = Time.now  #DateTime.strptime("#{status.lastdate} #{status.lasttime}")
	  job.save
		# if job.comment == 'Verification' && !job.device_id.nil?
		# 	device = DeliveryDevice.find job.device_id
		# 	device.status = 'verified'
		# 	device.status_time = Time.now
		# 	device.satus_reason = ''
		# end
  end

  def human_direct(status, job)
	  unless job.device_id.nil?
		  device = DeliveryDevice.find job.device_id
		  device.status= 'Hold'
		  device.status_time = Time.now
		  device.status_reason = status.outcome
		  device.save
	  end
		job.remote_id = nil
		job.status = 'Human'

	  job.end_time = job.status_time =Time.now # DateTime.strptime("#{status.lastdate} #{status.lasttime}")
		job.comment = status.outcome
		job.save
  end

	def failed_direct(status, job)
		job.remote_id = nil
		job.status = 'Failed'
		job.end_time = job.status_time = Time.now #DateTime.strptime("#{status.lastdate} #{status.lasttime}")
		job.comment = status.outcome
		job.save
	end

end
