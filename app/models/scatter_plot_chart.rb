class ScatterPlotChart
  attr_accessor :experiment, :x_axis, :y_axis,
                :x_axis_label, :y_axis_label,
                :x_axis_type, :y_axis_type,
                :x_axis_notation, :y_axis_notation,
                :chart_data, :linear_regression_data

  def initialize(experiment, x_axis, y_axis, additional=nil)
    @experiment = experiment
    @x_axis = x_axis
    @y_axis = y_axis

    @x_axis_label = experiment.input_parameter_label_for(x_axis) || x_axis
    @y_axis_label = experiment.input_parameter_label_for(y_axis) || y_axis

    additional ||= {}

    @x_axis_type = additional[:x_axis_type]
    @y_axis_type = additional[:y_axis_type]

    @x_axis_notation = additional[:x_axis_notation]
    @y_axis_notation = additional[:y_axis_notation]
  end

  def prepare_chart_data
    scatter_plot_csv = @experiment.create_scatter_plot_csv_for(@x_axis, @y_axis)

    @chart_data = Hash.new

    column_x_idx, column_y_idx, simulation_ind_idx = -1, -1, -1
    CSV.parse(scatter_plot_csv) do |row|
      if column_x_idx < 0
        column_x_idx = row.index(@x_axis)
        column_y_idx = row.index(@y_axis)
        simulation_ind_idx = row.index('simulation_run_ind')
      else
        if @chart_data.has_key? row[column_x_idx]
          @chart_data[row[column_x_idx]] << [row[column_y_idx], row[simulation_ind_idx]]
        else
          @chart_data[row[column_x_idx]] = [[row[column_y_idx], row[simulation_ind_idx]]]
        end
      end
    end

    x_values = []
    y_values = []
    @chart_data.each do |x_value, y_values_simulation_ids|
      y_values_simulation_ids.each do |y_value, simulation_id|
        x_values.push(x_value.to_f)
        y_values.push(y_value.to_f)
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
  
  def linear_regression_possible?
    @linear_regression_data.flatten.all? { |item| !item.nan? }
  end
end
