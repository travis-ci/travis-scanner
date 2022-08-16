task :manually_schedule_logs, [:from, :to, :force] => [ :environment ] do |t, args|
  args.with_defaults(:force => 'n')
  force = args[:force] == 'Y' ? true : false
  Rails.logger.info('Scheduling logs task started...')
  ManuallyScheduleLogs.new(args[:from], args[:to], force).call
end
