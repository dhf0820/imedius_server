class DeliveryHistory < ActiveRecord::Base
  belongs_to :patient
  belongs_to :visit
  belongs_to :account
  belongs_to :recipient
end