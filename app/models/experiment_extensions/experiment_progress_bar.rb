require 'scalarm/database/core'

require 'scalarm/database/model'

module ExperimentProgressBar
  CANVAS_WIDTH = 960.0
  MINIMUM_SLOT_WIDTH = 2.0
  PROGRESS_BAR_THRESHOLD = 10000

  def progress_bar_table
      table_name = "experiment_progress_bar_#{self.experiment_id}"
      Scalarm::Database::MongoActiveRecord.get_collection(table_name)
  end

  def parts_per_progress_bar_slot
    return 1 if self.experiment_size <= 0

    part_width = CANVAS_WIDTH / self.experiment_size
    [(MINIMUM_SLOT_WIDTH / part_width).ceil, 1].max
  end

  def progress_bar_update(simulation_id, update_type)
    return if self.experiment_size > PROGRESS_BAR_THRESHOLD and update_type == 'sent'

    parts_per_slot = parts_per_progress_bar_slot
    bar_index = ((simulation_id - 1) / parts_per_slot).floor

    increment_value = if update_type == 'done'
                        (self.experiment_size > PROGRESS_BAR_THRESHOLD) ? 1 : 2
                      elsif update_type == 'sent'
                        1
                      elsif update_type == 'rollback'
                        -1
                      elsif update_type == 'error'
                        -256
                      end

    begin
      result = progress_bar_table.update({bar_num: bar_index}, '$inc' => {bar_state: increment_value})
      bar = progress_bar_table.find_one({bar_num: bar_index})
      table_length = progress_bar_table.count
      color = compute_bar_color(bar)
      Scalarm::Database::Model::ExperimentProgressNotification.
          new(experiment_id: self.experiment_id,
               date: Time.now.to_i,
               bar_info: {
                   bar_num: bar["bar_num"],
                   tab_len: table_length,
                   color: color
               }
          ).save
     result
    rescue Exception => e
      Rails.logger.debug("Error in fastest update --- #{e}")
    end
  end

  def basic_progress_bar_info(experiment_size = -1)
    experiment_size = self.experiment_size if experiment_size < 0

    part_width = CANVAS_WIDTH / experiment_size
    parts_per_slot = [(MINIMUM_SLOT_WIDTH / part_width).ceil, 1].max
    number_of_bars = if parts_per_slot > 1 then
                       x = (experiment_size / parts_per_slot).ceil
                       if x * parts_per_slot < experiment_size
                        x + 1
                      else
                        x
                      end
                     else
                       experiment_size
                     end

    return parts_per_slot, number_of_bars
  end

  def progress_bar_color
    progress_bar_table.find({}, {:sort => [%w(bar_num ascending)]}).to_a.map { |bar_doc| compute_bar_color(bar_doc) }
  end

  def compute_bar_color(bar_doc)
    color_step = 200.to_f / (2 * bar_doc['bar_parts'])
    bar_state = bar_doc['bar_state']

    color = bar_state == 0 ? 0 : (55 + color_step * bar_state).to_i
    color = -1 if bar_state < 0

    [color, 255].min
  end

  def update_all_bars
    parts_per_slot = parts_per_progress_bar_slot

    Rails.logger.debug("UPDATE ALL BARS --- #{parts_per_slot}")
    instance_id = 1
    while instance_id <= self.experiment_size
      update_bar_state(instance_id)
      instance_id += parts_per_slot
    end
  end

  def update_bar_state(instance_id)
    return if self.nil? or (not self.is_running)
    experiment_id, experiment_size = self.experiment_id, self.experiment_size

    a = Time.now
    Rails.logger.debug("update_bar_state(#{instance_id})")
    parts_per_slot = parts_per_progress_bar_slot
    bar_index = ((instance_id - 1) / parts_per_slot).floor

    return if is_update_free_time(bar_index)

    first_id = [bar_index*parts_per_slot + 1, experiment_size].min
    last_id = [(bar_index+1)*parts_per_slot, experiment_size].min
    query_hash = {'index' => {'$in' => (first_id..last_id).to_a}}
    option_hash = {fields: %w(to_sent is_done is_error)}

    #Rails.logger.debug("Query hash => #{query_hash} --- Option hash => #{option_hash}")
    new_bar_state = 0
    simulation_runs.where(query_hash, option_hash).each do |sim_run|
      # Rails.logger.debug("Instance_doc --- #{instance_doc}")
      if sim_run.is_error
        new_bar_state -= 256
      elsif sim_run.is_done
        new_bar_state += 2
      elsif not sim_run.to_sent
        new_bar_state += 1
      end
    end

    begin
      #Rails.logger.debug("New bar state = #{{:bar_num => bar_index}} #{{'$set' => { :bar_state => new_bar_state }}}")
      if color_of_bar(bar_index) != new_bar_state
        progress_bar_table.update({bar_num: bar_index}, '$set' => {bar_state: new_bar_state})
      end
    rescue Exception => e
      Rails.logger.debug("Error --- #{e}")
    end

    Rails.logger.debug("Updating bar state took #{Time.now - a}")
  end

  def is_update_free_time(bar_index)
    cache_key = "progress_bar_#{self.experiment_id}_#{bar_index}"
    bar_last_update = Rails.cache.read(cache_key)
    Rails.logger.debug("Bar last update - #{bar_last_update}")
    Rails.cache.write(cache_key, Time.now, :expires_in => 30) if bar_last_update.nil?
    not bar_last_update.nil?
  end

  def color_of_bar(bar_index)
    compute_bar_color(progress_bar_table.find_one({bar_num: bar_index}))
  end

  def create_progress_bar_table
    bar_created, counter = false, 0
    while (not bar_created) and counter < 5
      counter += 1
      begin
        progress_bar = progress_bar_table
        progress_bar.drop
        progress_bar = progress_bar_table
        progress_bar.create_index([['bar_num', Mongo::ASCENDING]])
        bar_created = true

        return progress_bar

      # experimental - rescuing only StandardError
      rescue => e
        Rails.logger.error("Couldn't create progress bar table")
      end
    end

    nil
  end

  def insert_initial_bar
    progress_bar_data = []
    parts_per_slot, number_of_bars = basic_progress_bar_info(self.experiment_size)

    0.upto(number_of_bars - 1) do |bar_num|
      bar_doc = {'bar_num' => bar_num, 'bar_parts' => parts_per_slot, 'bar_state' => 0}
      if (bar_num == number_of_bars - 1) and (parts_per_slot > 1) and (self.experiment_size != number_of_bars * parts_per_slot)
        bar_doc['bar_parts'] = number_of_bars * parts_per_slot - self.experiment_size
        puts "Number of parts in the last bar #{bar_doc['bar_parts']}"
      end

      next if bar_doc['bar_parts'] <= 0
      progress_bar_data << bar_doc
    end

    progress_bar_table = create_progress_bar_table
    progress_bar_table.insert(progress_bar_data)
  end

end
