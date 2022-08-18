task :manually_schedule_logs_by_time_frame, [:from, :to, :force] => [ :environment ] do |t, args|
  # Check and convert force value from n/Y to false/true
  args.with_defaults(:force => 'n')
  force = args[:force] == 'Y' ? true : false

  Rails.logger.info('Scheduling logs by time frame task started...')

  # Check and convert the from/to dates from string to time
  from = Time.parse(args[:from])
  to = Time.parse(args[:to])

  ManuallyScheduleLogs.new(force).schedule_logs_by_time_frame(from, to)
end

task :manually_schedule_logs_by_job_ids, [:job_ids, :force] => [ :environment ] do |t, args|
  # Check and convert force value from n/Y to false/true
  args.with_defaults(:force => 'n')
  force = args[:force] == 'Y' ? true : false

  Rails.logger.info('Scheduling logs by job ids task started...')

  # Check and convert job_ids value from string to an integer array
  job_ids = args[:job_ids].split.grep(/\d+/, &:to_i)

  ManuallyScheduleLogs.new(force).schedule_logs_by_job_ids(job_ids)
end