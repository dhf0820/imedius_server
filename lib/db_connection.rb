require 'active_record'
require 'pg'

class DbConnection
  def initialize
    @dbconfig = YAML.load(File.read('config/database.yml'))
    env = ENV['PG_ENV']
    env = 'development' if env.blank?
    puts "Using #{env} mode"
    ActiveRecord::Base.establish_connection @dbconfig[env]
  end

end
