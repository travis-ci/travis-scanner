require 'sidekiq-scheduler'

module Travis
  module Scanner
    class Scheduler
      include Sidekiq::Worker

      def perform
        Rails.logger.info('Queueing logs...')
        QueueLogsService.new.call
      end
    end
  end
end
