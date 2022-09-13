task queue_logs: :environment do
  loop do
    Rails.logger.info('Queueing logs...')
    QueueLogs.new.call
    sleep(Settings.queue_interval)
  end

  Rails.logger.info('exit')
end
