task :schedule_logs, [:from, :to] => [ :environment ] do |t, args|
  Rails.logger.info('Scheduling logs task started...')
  ScheduleLogs::new(args[:from], args[:to]).call
end
