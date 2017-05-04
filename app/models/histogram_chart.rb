require 'csv'
require 'rinruby'
require 'tempfile'
require 'uri'

class HistogramChart
  attr_accessor :experiment, :resolution, :moe_name,
                :bucket_name, :buckets, :stats, :type,
                :x_axis_notation, :y_axis_notation
  include URI::Escape
  def initialize(experiment, moe_name, resolution, type,  additional =nil)
    @experiment = experiment
    @moe_name = URI.escape(moe_name)
    @resolution = resolution
    @stats = { ex_min: 0 }
    @type = type
    @x_axis_notation = URI.escape(additional[:x_axis_notation])
    @y_axis_notation = URI.escape(additional[:y_axis_notation])
    if type == "string"
      prepare_chart_data_for_string_type
    else
      prepare_chart_data
    end

  end

  def prepare_chart_data_for_string_type
    @result_csv = @experiment.create_result_csv_for(@moe_name)
    result_file = Tempfile.new('histogram')
    IO.write(result_file.path, @result_csv)

    @resolution = multi_dim_array_with_results.uniq(&:last).size

    @bucket_width = @resolution

    result_file.unlink
  end

  def prepare_chart_data
    @result_csv = @experiment.create_result_csv_for(@moe_name)
    #Rails.logger.debug("Result csv = #{ @result_csv }")
    result_file = Tempfile.new('histogram')
    IO.write(result_file.path, @result_csv)
    #result_file.write(@result_csv)

    #Rails.logger.debug("result_file.path - #{result_file.path}")

    rinruby = RinRuby.new(false)
    rinruby.eval("
      experiment_data <- read.csv(\"#{result_file.path}\")
      ex_min <- min(experiment_data$#{@moe_name})
      ex_max <- max(experiment_data$#{@moe_name})
      ex_sd <- sd(experiment_data$#{@moe_name})
      ex_mean <- mean(experiment_data$#{@moe_name})
    ")

    @stats = {
        ex_min: ('%.2f' % rinruby.ex_min).to_f,
        ex_max: ('%.2f' % rinruby.ex_max).to_f,
        ex_sd: ('%.2f' % rinruby.ex_sd).to_f,
        ex_mean: ('%.2f' % rinruby.ex_mean).to_f
    }

    @bucket_width = (@stats[:ex_max] - @stats[:ex_min]) / @resolution

    if @stats[:ex_max] == @stats[:ex_min]
      @bucket_width = @stats[:ex_max]
      @resolution = 1
    end

    rinruby.quit

    result_file.unlink
  end


  def multi_dim_array_with_results
    rows_of_csv_result = @result_csv.split("\n")
    multi_dim_array_with_results = []

    rows_of_csv_result.each_with_index do |x, index|
      if index != 0
        multi_dim_array_with_results.push(x.split(","))
      end
    end
    return multi_dim_array_with_results
  end


  def bucket_names
    if type == 'string'
      results = multi_dim_array_with_results

      array_with_uniq_and_sort_result = results.uniq(&:last)
      array_with_uniq_and_sort_result = array_with_uniq_and_sort_result.sort_by(&:last)

      return array_with_uniq_and_sort_result.map {|row| row[row.size - 1]}

    else
      Array.new(@resolution) { |ind|
        #if ind == resolution - 1
        #  "[#{ '%.1f' % (min_value + slice_width * ind) }-#{ '%.1f' % (min_value + slice_width * (ind + 1)) }]"
        #else
        format_modifier = (x_axis_notation == 'scientific' ? 'E' : 'f')
        "[#{ "%.#{leading_nums}#{format_modifier}" % (stats[:ex_min] + @bucket_width * ind) }-#{ "%.#{leading_nums}f" % (@stats[:ex_min] + @bucket_width * (ind + 1)) })"

        #end
      }
    end
  end

  def buckets
    buckets = Array.new(@resolution) { 0 }
    if type == 'string'

      array_with_result = multi_dim_array_with_results

      array_with_sort_column_of_result = array_with_result.sort_by(&:last)
      array_with_only_sorted_values_of_result = array_with_sort_column_of_result.map {|row| row[row.size - 1]}

      last_checked_symbol = ''
      current_index = 0
      array_with_only_sorted_values_of_result.each_with_index do |x, index|
        if index == 0
          last_checked_symbol = x
        else
          if x != last_checked_symbol
            current_index += 1
            last_checked_symbol = x
          end
        end
        buckets[current_index] += 1
      end
    else
      column_index = -1
      CSV.parse(@result_csv) do |row|
        if column_index < 0 then
          column_index = row.index(@moe_name)
        else
          if @bucket_width == 0.0
            buckets[0] += 1
          else
            buckets[ [ ((row[column_index].to_f - @stats[:ex_min]) / @bucket_width).floor, buckets.size - 1 ].min ] += 1
          end
        end
      end
    end
    return buckets
  end

  def leading_nums
    leading_nums_count = 0
    @stats.each do |key, value|
      split_value = value.to_s.split('.')
      if split_value.size == 2 and leading_nums_count < split_value.last.size
        leading_nums_count = split_value.last.size
      end
    end

    leading_nums_count
  end

end