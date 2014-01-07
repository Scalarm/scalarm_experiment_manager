require_relative '../../cloud_client'

class AmazonClient < CloudClient
  def self.short_name
    'amazon'
  end
  def self.full_name
    'Amazon Elastic Compute Cloud'
  end
end