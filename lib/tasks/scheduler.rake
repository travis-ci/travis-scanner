task :schedule_logs, [:from, :to] => [ :environment ] do |t, args|
  ScheduleLogs::new(args[:from], args[:to]).call
end
