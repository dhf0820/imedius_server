#!/usr/bin/env ruby
puts "$0: #{File.basename($0)}"
puts "path: #{File.expand_path(File.dirname(__FILE__))}"
ENV['DHF'] = "#{File.expand_path(File.dirname(__FILE__))}"
require 'pry'
$path = File.expand_path(File.dirname(__FILE__))
$service = File.basename($0)
#include EfaxDeliver
require_relative './lib/cli.rb'


puts "in ImediusDelivery executable "
#extractor = Extractor::Extractor.new
CLI.execute