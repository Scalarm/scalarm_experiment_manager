class ScatterPlotChart
  attr_accessor :experiment, :x_axis, :y_axis, :x_axis_label, :y_axis_label, :chart_data

  def initialize(experiment, x_axis, y_axis)
    @experiment = experiment
    @x_axis = x_axis
    @y_axis = y_axis

    @x_axis_label = experiment.input_parameter_label_for(x_axis) || x_axis
    @y_axis_label = experiment.input_parameter_label_for(y_axis) || y_axis
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
  end
end