require 'csv'
require 'rinruby'
require 'tempfile'

class HistogramChart
  attr_accessor :experiment, :resolution, :moe_name, :bucket_name, :buckets, :stats

  def initialize(experiment, moe_name, resolution)
    @experiment = experiment
    @moe_name = moe_name
    @resolution = resolution
    @stats = { ex_min: 0 }

    prepare_chart_data
  end

  def prepare_chart_data
    @result_csv = @experiment.create_result_csv_for(@moe_name)
    #Rails.logger.debug("Result csv = #{ @result_csv }")
    result_file = Tempfile.new('result_file')
    IO.write(result_file.path, @result_csv)
    #result_file.write(@result_csv)

    #Rails.logger.debug("result_file.path - #{result_file.path}")

    rinruby = Rails.configuration.eusas_rinruby
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

    result_file.unlink
  end

  def bucket_names
    Array.new(@resolution) { |ind|
      #if ind == resolution - 1
      #  "[#{ '%.1f' % (min_value + slice_width * ind) }-#{ '%.1f' % (min_value + slice_width * (ind + 1)) }]"
      #else
        "[#{ "%.#{leading_nums}f" % (stats[:ex_min] + @bucket_width * ind) }-#{ "%.#{leading_nums}f" % (@stats[:ex_min] + @bucket_width * (ind + 1)) })"
      #end
    }
  end

  def buckets
    buckets = Array.new(@resolution) { 0 }

    column_index = -1
    CSV.parse(@result_csv) do |row|
      if column_index < 0 then
        column_index = row.index(@moe_name)
      else
        buckets[ [ ((row[column_index].to_f - @stats[:ex_min]) / @bucket_width).floor, buckets.size - 1 ].min ] += 1
      end
    end

    buckets
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