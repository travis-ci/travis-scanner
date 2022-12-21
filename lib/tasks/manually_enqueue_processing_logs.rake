require 'optparse/date'

task manually_enqueue_processing_logs: :environment do
  options = { force: false }

  o = OptionParser.new
  o.banner = 'Usage: rake manually_enqueue_processing_logs -- [options]'

  o.on('--ids=log_ids', Array) { |log_ids| options[:log_ids] = log_ids.map(&:to_i) }
  o.on('--from=start_date', Date) { |start_date| options[:start_date] = start_date }
  o.on('--to=end_date', Date) { |end_date| options[:end_date] = end_date }
  o.on('-f', '--[no-]force', 'Forcefully schedule logs') { |f| options[:force] = f }

  args = o.order!(ARGV) {} # Needed for optparse to work within the rake task

  begin
    o.parse!(args)
  rescue => e
    abort(e.message)
  end

  if options[:start_date].blank? && options[:end_date].blank? && options[:log_ids].blank?
    abort('Either log ids or time frame must be provided')
  end

  if (options[:start_date].blank? || options[:end_date].blank?) && options[:log_ids].blank?
    abort('Both start date and end date must be provided')
  end

  ManuallyEnqueueProcessingLogsService.call(options)
end
