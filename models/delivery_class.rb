# Contains default information for all delivery devices of this class such as failure delays, max failures
# Notification on max failure
# identifies the specific DeliveryService that will actually handle the delivery

class DeliveryClass < ActiveRecord::Base
  has_many :delivery_devices
end