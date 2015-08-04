require 'json'
class ScatterPlotChart
  attr_accessor :experiment, :x_axis, :y_axis,
                :x_axis_label, :y_axis_label,
                :x_axis_type, :y_axis_type,
                :chart_data, :linear_regression_data,
                :type_of_x, :type_of_y,
                :categories_for_x, :categories_for_y

  def initialize(experiment, x_axis, y_axis, type_of_x, type_of_y, additional=nil)
    @experiment = experiment
    @x_axis = x_axis
    @y_axis = y_axis
    @type_of_x = type_of_x
    @type_of_y = type_of_y
    @x_axis_label = experiment.input_parameter_label_for(x_axis) || x_axis
    @y_axis_label = experiment.input_parameter_label_for(y_axis) || y_axis
    @categories_for_x  = []
    @categories_for_y  = []
    additional ||= {}

    @x_axis_type = additional[:x_axis_type]
    @y_axis_type = additional[:y_axis_type]

  end

  def prepare_chart_data
    scatter_plot_csv = @experiment.create_scatter_plot_csv_for(@x_axis, @y_axis)
    @chart_data = Hash.new

    array_for_single_x = array_of_categories_for_axis(0)
    array_for_single_y = array_of_categories_for_axis(1)

    column_x_idx, column_y_idx, simulation_ind_idx = -1, -1, -1
    CSV.parse(scatter_plot_csv) do |row|
      if column_x_idx < 0
        column_x_idx = row.index(@x_axis)
        column_y_idx = row.index(@y_axis)
        simulation_ind_idx = row.index('simulation_run_ind')
      else
        if type_of_x === "string" && type_of_y === "string"
          if @chart_data.has_key? array_for_single_x.index(row[column_x_idx])
            @chart_data[array_for_single_x.index(row[column_x_idx])] << [array_for_single_y.index(row[column_y_idx]), row[simulation_ind_idx]]
          else
            @chart_data[array_for_single_x.index(row[column_x_idx])] = [[array_for_single_y.index(row[column_y_idx]), row[simulation_ind_idx]]]
          end
        elsif type_of_x === "string"
          if @chart_data.has_key? array_for_single_x.index(row[column_x_idx])
              @chart_data[array_for_single_x.index(row[column_x_idx])] << [row[column_y_idx], row[simulation_ind_idx]]
          else
              @chart_data[array_for_single_x.index(row[column_x_idx])] = [[row[column_y_idx], row[simulation_ind_idx]]]
          end
        elsif type_of_y === "string"
          if @chart_data.has_key? row[column_x_idx]
            @chart_data[row[column_x_idx]] << [array_for_single_y.index(row[column_y_idx]), row[simulation_ind_idx]]
          else
            @chart_data[row[column_x_idx]] = [[array_for_single_y.index(row[column_y_idx]), row[simulation_ind_idx]]]
          end
        else
          if @chart_data.has_key? row[column_x_idx]
            @chart_data[row[column_x_idx]] << [row[column_y_idx], row[simulation_ind_idx]]
          else
              @chart_data[row[column_x_idx]] = [[row[column_y_idx], row[simulation_ind_idx]]]
          end
        end
      end
    end

    if (type_of_x != "string" && type_of_y != "string")
      x_values = []
      y_values = []
      @chart_data.each do |x_value, y_values_simulation_ids|
        y_values_simulation_ids.each do |y_value, simulation_id|
          if type_of_x === 'string'
            x_values.push(x_value)
          else
            x_values.push(x_value.to_f)
          end

          if type_of_y === 'string'
            y_values.push(y_value)
          else
            y_values.push(y_value.to_f)
          end
        end
      end

      rinruby = Rails.configuration.r_interpreter
      rinruby.x_values = x_values
      rinruby.y_values = y_values
      rinruby.eval("res = lm(y_values~x_values)
                b = coef(res)[1]
                a = coef(res)[2]")
      sorted_array = x_values.sort()
      x_min, x_max = sorted_array[0], sorted_array[sorted_array.length-1]
      a = rinruby.pull("a").to_f
      b = rinruby.pull("b").to_f
      x1, y1 = x_min, a*x_min+b
      x2, y2 = x_max, a*x_max+b

      @linear_regression_data = [[x1, y1],[x2, y2]]
    end

    if type_of_x === "string"
      @categories_for_x = array_for_single_x
    end

    if type_of_y === "string"
      @categories_for_y = array_for_single_y
    end

  end
  
  def linear_regression_possible?
    @linear_regression_data.flatten.all? { |item| !item.nan? }
  end

  def array_of_categories_for_axis(number_of_column)
    scatter_plot_csv = @experiment.create_scatter_plot_csv_for(@x_axis, @y_axis)
    array = scatter_plot_csv.split("\n")
    array.delete_at(0)
    array.each_with_index { |item, index |
      array[index] = item.split(",")
    }
    array = array.map {|row| row[number_of_column]}
    array = array.sort.uniq
    return array
  end

end
