class GridJob < ActiveRecord::Base
  belongs_to :user
  
  def self.plgrid_monitoring_function
    Rails.logger.debug("Starting Grid Jobs monitoring")

    while true do
      # Rails.logger.debug("GridJobs count: #{GridJob.all.size}")
      GridJob.all.each do |gj|
        # Rails.logger.debug("Grid job - time_limit = #{gj.time_limit} + #{gj.created_at} --- Time.now = #{Time.now}")
        if gj.created_at + gj.time_limit  < Time.now
          logger.info("Grid job with id: #{gj.id} --- #{gj.grid_id} has been deleted")
          GridJob.delete(gj.id)
        end  
      end

      sleep(60)
    end
  end
end
