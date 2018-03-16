require_relative 'delivery_profile.rb'
require_relative 'delivery_device.rb'
require_relative 'clinical_document.rb'
require_relative 'physician.rb'
require_relative 'delivery_class.rb'
require_relative 'document_type.rb'


class DeliveryRequest < ActiveRecord::Base
	belongs_to :delivery_job

	# TODO Handle coversheets
	def self.request_delivery(raw, cd_id)

		dr = DeliveryRequest.new
		phy = Physician.find(raw.phy_id)
		cd = ClinicalDocument.find(cd_id)
		dps = DeliveryProfile.where(phy_id: phy.id, doc_type_id: cd.type_id)
		if dps.nil?
			puts "   #{phy.name} does not have a profile for document typwe: #{cd.type_id}"
		end
		puts "#{phy.name} has #{dps.count} profiles for document type: #{cd.type_id}"
		# There is at least one profile  Check for no delivery
		dps.each do |profile|
			puts "\n Queue delivery to device #{profile.device_id}"
			dd = DeliveryDevice.find profile.device_id
			unless dd.name == 'NONE'  # normally one one.  If they have oen with none and one reasl undetermined if will be delivered
				dr.queue_it(cd, phy, profile, dd)    # physician wants the queue however they want it
			else
				puts "   #{phy.name} does not want this document profile is NONE"
			end
		end
	end

	def queue_it(cd, phy, dp, dd)
		puts "    #{phy.name} wants this document via #{dd.name}"
		self.doc_id = cd.id
		self.phy_id = phy.id
		self.profile_id = dp.id
		self.device_id = dd.id
		self.device_class_id = dd.class_id
		# retrieve the args from supporting classes

		dc = DeliveryClass.find dd.class_id
		dt = DocumentType.find dp.doc_type_id


		self.command = dd.command    # fax number, print command, nightsort command
		self.device_class_id = dc.id


		if dt.priority > dp.priority                  # Use the highest priority between doc_type and profile
			self.priority = dt.priority
		else
			self.priority = dp.priority
		end
		if dd.verify_date.nil?                        #queue waiting for device verification
			self.needs_verification = true
			#TODO set delivery kill_time waiting for verification
		end
		if dd.delay_time.nil?                         # minimum time to delay between send attempts
			self.delay_time = dc.delay_time
		else
			self.delay_time= dd.delay_time
		end
		if dd.max_fails.nil?                          # How many attempts shold we make to deliver before sending to night
			self.max_tries = dc.max_fails
		else
			self.max_tries = dd.max_fails
		end
		self.queue_time = Time.now
		self.num_pages = cd.current_version.pages      # how many pages are we delivering

		res = self.save
		puts "Save delivery request returned #{res}"

	end

	def clinical_image
		doc = ClinicalDocument.find(doc_id)
		doc.archived_image.image
	end
end