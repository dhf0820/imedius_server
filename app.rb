require 'pry'

require './lib/db_connection'
require './models/physician'


$dbconnection = DbConnection.new

p = Physician.first
binding.pry
puts "First Physician Email----- #{p.email}"
