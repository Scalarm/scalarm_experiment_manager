require 'json'

module InfrastructuresHelper

  def infrastructures_list_to_select_hash(infrastructures_hash)
    infrastructures_hash.map do |first|
      first[:children] = [first.clone] unless first.has_key? :children
      [
          first[:name], first[:children].map do |second|
            [second[:name], second.to_json]
          end
      ]
    end
  end

end
