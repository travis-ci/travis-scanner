#!/usr/bin/ruby

require File.expand_path('../../../config/environment', __FILE__)

require 'optparse'
require 'time'

options = { :force => false }
OptionParser.new do |opts|
  opts.banner = "Usage: scheduler.rb [options]"
  opts.on('--force') { |_| options[:force] = true }
  opts.on('--from start_date') do |start_date|
    begin
      options[:start_date] = Time.parse(start_date)
    rescue ArgumentError
      raise OptionParser::ParseError.new("Invalid start date provided")
    end
  end
  opts.on('--to end_date') do |end_date|
    begin
      options[:end_date] = Time.parse(end_date)
    rescue ArgumentError
      raise OptionParser::ParseError.new("Invalid end date provided")
    end
  end
  opts.on('--ids log_ids') do |log_ids|
    begin
      options[:log_ids] = log_ids.gsub(/\s+/, "").split(',').grep(/\d+/, &:to_i)
    rescue Exception
      raise OptionParser::ParseError.new("Invalid value provided for log ids, please provide comma separated ids")
    end
  end
end.parse!

if not options[:start_date] and not options[:end_date] and not options[:log_ids]
  raise OptionParser::ParseError.new("Either log ids or time frame must be provided")
end

if (options[:start_date] and not options[:end_date]) or (options[:end_date] and not options[:start_date])
  raise OptionParser::ParseError.new("Both start date and end date must be provided")
end

ManuallyScheduleLogs.new(options[:start_date], options[:end_date], options[:log_ids], options[:force]).call
