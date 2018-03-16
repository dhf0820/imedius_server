# The Data structure that manages every of a type that is delivered
# Each ImediusDelivery Device has its own queue
# We do not care what is delivered via the device or the format of the delivery. Deliver formats as necessary


class DeliveryQueue < ActiveRecord::Base
  belongs_to :physician
  belongs_to :delivery_device
  belongs_to :delivery_class
  belongs_to :archive

end