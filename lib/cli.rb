require 'optparse'
require_relative './efax_delivery.rb'
require_relative './queue_processor.rb'



  class CLI
    def self.execute()

      options = {
          degub: :WARN,
          path: nil,
          environment: 'IDS_EFAX_SERVER',
          mode: 'test'
      }
      mandatory_options = %w( )

      @parser = OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^          /,'')
          Receive queue messages and delivery faxes
  
          Usage: #{File.basename($0)} [options]
  
          Options are:
        BANNER
        opts.separator ""

        opts.on("-d","--debug LEVEL", String,
                "The level of loging detail.",
                "FATAL",
                "ERROR",
                "WARN",
                "INFO",
                "DEBUG",
                "DEBUG1-9",
                "If not used will used the value defined in the System.yml config file",
                " "
        ) {|arg| options[:debug] = arg}
        opts.on("-e","--environment NAME", String,
                "Specifies the Environment Variable that defines the base of the system",
                "Default: IHIDS",
                " ") {|arg| options[:environment] = arg}
        opts.on("-h", "--help",
                "Show this help message.",
                " ") { puts opts; exit }

        opts.on("-p", "--path PATH", String,
                "Path to the base application directory",
                "If given, overrides any environment option specified.",
                " "
        ) { |arg| options[:path] = arg }

        opts.on("-m", "--mode TEST|LIVE", String,
                "Runtime mode. Default is test.",
                " "
        ) { |arg| options[:mode] = arg}

	      opts.on("-s", "--service  Name", String,
	              "Service(DeliveryClassName)",
	              "Default: Efax",
	              " "
	      ) { |arg| options[:service] = arg}
        begin
          opts.parse!(ARGV)
        rescue OptionParser::InvalidOption
          puts opts; exit
        end

        if mandatory_options && mandatory_options.find { |option| options[option.to_sym].nil? }
          binding.pry
          puts opts; exit
        end

      end

      env = options[:environment]

      debug = options[:debug]
      path = options[:path]
      @mode = options[:mode].downcase
      options[:service] ||= 'EFax'


      if ENV[env].nil?
        puts "\nThe #{env} environment variable is not set up. Please do so and restart.\n"
        exit
      end

      if(path)
        current_path = path
      else
        current_path = ENV[env]
      end

      puts "Starting FaxDelivery:  using #{current_path} in #{@mode} mode"


      #begin
        fax = EfaxDelivery.new(@mode, options[:service], current_path)


      queue_processor = QueueProcessor.new(fax)

      queue_processor.process_queue()

      # remove the working if it is empty. Otherwise it stays and notify system manager that some files did not get processed
     # puts "Remove working: #{queue_processor.working_path}"
     # Dir.rmdir(queue_processor.working_path)
      # f = File.open('test.txt')
      # buf = f.read
      # f.close
      # processor.process_buffer(buf)




      # ARGV.each do|a|
      #   puts "Argument: #{a}"
      # end
      #     binding.pry
    end

    def mode
      @mode
    end

  end


