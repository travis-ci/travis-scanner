class ScanResultsController < ApplicationController
  def index
    scan_results = ScanResult.where(repository_id: params[:repository_id])
                             .where(issues_found: 1..)
                             .where(created_at: Settings.scan_logs_availability_days.days.ago..)
                             .order(created_at: :desc)
                             .page(params[:page])
                             .per(params[:limit])

    render json: {
      scan_results: scan_results.map { |scan_result| ::ScanResultSerializer.new(scan_result) },
      total_count: scan_results.total_count
    }
  end

  def show
    scan_result = ScanResult.where(created_at: Settings.scan_logs_availability_days.days.ago..)
                            .find(params[:id])

    render json: { scan_result: ::ScanResultSerializer.new(scan_result) }
  end
end
