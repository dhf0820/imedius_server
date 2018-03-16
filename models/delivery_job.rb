class DeliveryJob < ActiveRecord::Base
	has_many :delivery_requests

end