
class ExperimentProgressBar < ActiveRecord::Base
  belongs_to :experiment
  belongs_to :experiment_instance_db

  CANVAS_WIDTH = 960.0
  MINIMUM_SLOT_WIDTH = 2.0

  def insert_initial_bar(experiment_size)
    progress_bar_data = []
    parts_per_slot, number_of_bars = basic_progress_bar_info(experiment_size)

    0.upto(number_of_bars - 1) do |bar_num|
      bar_doc = { "bar_num" => bar_num, "bar_parts" => parts_per_slot, "bar_state" => 0 }
      if (bar_num == number_of_bars - 1) and (parts_per_slot > 1)
        bar_doc["bar_parts"] = experiment_size - number_of_bars * parts_per_slot
      end

      next if bar_doc["bar_parts"] <= 0
      progress_bar_data << bar_doc
    end

    progress_bar_table = create_progress_bar_table
    progress_bar_table.insert(progress_bar_data)
  end

  def basic_progress_bar_info(experiment_size = -1)
    experiment_size = self.experiment.experiment_size if experiment_size < 0

    part_width = CANVAS_WIDTH / experiment_size
    parts_per_slot = [(MINIMUM_SLOT_WIDTH / part_width).ceil, 1].max
    number_of_bars = if parts_per_slot > 1 then
                       (experiment_size / parts_per_slot).ceil
                     else
                       experiment_size
                     end

    return parts_per_slot, number_of_bars
  end

  def progress_bar_table
    table_name = "experiment_progress_bar_#{self.experiment_id}"
    ExperimentInstanceDb.default_instance.default_connection.collection(table_name)
  end

  def create_progress_bar_table
    bar_created, counter = false, 0
    while (not bar_created) and counter < 5
      counter += 1
      begin
        progress_bar = progress_bar_table
        progress_bar.create_index([["bar_num", Mongo::ASCENDING]])
        bar_created = true
        
        return progress_bar 
      rescue Exception => e
        Rails.logger.error("Couldn't create progress bar table")
      end
    end

    nil
  end
  
  def update_all_bars
    parts_per_slot, number_of_bars = basic_progress_bar_info
    
    Rails.logger.debug("UPDATE ALL BARS --- #{parts_per_slot}")
    instance_id = 1
    while instance_id <= self.experiment.experiment_size
      update_bar_state(instance_id)
      instance_id += parts_per_slot
    end
  end

  def compute_bar_color(bar_doc)
    color_step = 200.to_f / (2 * bar_doc["bar_parts"])
    bar_state = bar_doc["bar_state"]

    color = bar_state == 0 ? 0 : (55 + color_step * bar_state).to_i
    # Rails.logger.debug("Parts: #{bar_doc["bar_parts"]} --- Bar state: #{bar_state} --- Color step: #{color_step} --- Color: #{color}")
    [color, 255].min
  end

  def color_of_bar(bar_index)
    compute_bar_color(progress_bar_table.find_one({"bar_num" => bar_index}))
  end

  def progress_bar_color
    progress_bar_table.find({},{:sort => [["bar_num", "ascending"]]}).to_a.map{ |bar_doc| compute_bar_color(bar_doc) }
  end

  def color_of_bar_for_instance(instance)
    parts_per_slot, number_of_bars = basic_progress_bar_info
    bar_index = ((instance.id - 1) / parts_per_slot).floor
    color = compute_bar_color(progress_bar_table.find_one({"bar_num" => bar_index}))

    return bar_index, color, number_of_bars
  end
  
  def update_bar_state(instance_id)
    return if self.experiment.nil? or (not self.experiment.is_running)
    experiment_id, experiment_size = self.experiment.id, self.experiment.experiment_size

    a = Time.now
    Rails.logger.debug("update_bar_state(#{instance_id})")
    parts_per_slot, number_of_bars = basic_progress_bar_info
    bar_index = ((instance_id - 1) / parts_per_slot).floor

    return if is_update_free_time(bar_index)

    first_id = [bar_index*parts_per_slot + 1, experiment_size].min
    last_id = [(bar_index+1)*parts_per_slot, experiment_size].min
    query_hash = {"id" => {"$in" => (first_id..last_id).to_a}}
    option_hash = {:fields => ["to_sent", "is_done"]}

    #Rails.logger.debug("Query hash => #{query_hash} --- Option hash => #{option_hash}")
    new_bar_state = 0
    ExperimentInstance.raw_find_by_query(experiment_id, query_hash, option_hash).each do |instance_doc|
      #Rails.logger.debug("Instance_doc --- #{instance_doc}")
      if instance_doc["is_done"]
        new_bar_state += 2
      elsif not instance_doc["to_sent"]
        new_bar_state += 1
      end
    end

    #Rails.logger.debug("Bar index - #{bar_index} --- Number of bars - #{number_of_bars} --- New bar state - #{new_bar_state}")
    begin
      #Rails.logger.debug("New bar state = #{{:bar_num => bar_index}} #{{'$set' => { :bar_state => new_bar_state }}}")
      if color_of_bar(bar_index) != new_bar_state
        progress_bar_table.update({:bar_num => bar_index}, '$set' => {:bar_state => new_bar_state})
      end
    rescue Exception => e
      Rails.logger.debug("Error --- #{e}")
    end

    Rails.logger.debug("Updating bar state took #{Time.now - a}")
  end

  def fast_update_bar_state(simulation_id, update_type)
    return if self.experiment.nil? or (not self.experiment.is_running)

    a = Time.now
    Rails.logger.debug("fast_update_bar_state(#{simulation_id})")
    parts_per_slot, number_of_bars = basic_progress_bar_info
    bar_index = ((simulation_id - 1) / parts_per_slot).floor

    increment_value = if update_type == "done"
                        (self.experiment.experiment_size < 10000) ? 1 : 2
                      elsif update_type == "sent"
                        1
                      elsif update_type == "rollback"
                        -1
                      end

    begin
      progress_bar_table.update({:bar_num => bar_index}, "$inc" => {:bar_state => increment_value})
    rescue Exception => e
      Rails.logger.debug("Error in fast update --- #{e}")
    end

    Rails.logger.debug("Fast updating bar state took #{Time.now - a}")
  end

  def drop
    progress_bar_table.drop
  end

  private

  def is_update_free_time(bar_index)
    cache_key = "progress_bar_#{self.experiment_id}_#{bar_index}"

    bar_last_update = Rails.cache.read(cache_key)
    Rails.logger.debug("Bar last update - #{bar_last_update}")
    Rails.cache.write(cache_key, Time.now, :expires_in => 30) if bar_last_update.nil?

    not bar_last_update.nil?
  end

end
