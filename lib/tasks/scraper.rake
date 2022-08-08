task queue_logs: :environment do
  puts 'Queueing logs...'

  loop do
    QueueLogs.new.call
    sleep(Settings.queue_interval)
  end

  puts 'exit'
end
