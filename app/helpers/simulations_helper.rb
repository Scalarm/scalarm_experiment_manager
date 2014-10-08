module SimulationsHelper

  def parametrization_options(parameter)
    self.send("options_for_#{parameter["type"]}")
  end

  def common_parametrizations
    [
        [ t('experiments.parameters.parametrization.value'), 'value' ],
        [ t('experiments.parameters.parametrization.custom'), 'custom' ]
    ]
  end

  def numeric_parametrizations
    [
        [ t('experiments.parameters.parametrization.range'), 'range' ],
        [ t('experiments.parameters.parametrization.gauss'), 'gauss' ],
        [ t('experiments.parameters.parametrization.uniform'), 'uniform' ]
    ]
  end

  def options_for_integer
    common_parametrizations + numeric_parametrizations
  end

  def options_for_float
    common_parametrizations + numeric_parametrizations
  end

  def options_for_string
    common_parametrizations
  end

  def select_doe_type
    options_for_select([
                           ['Near Orthogonal Latin Hypercubes', 'nolhDesign'],
                           ['2^k', '2k'],
                           ['2^(k-1)', '2k-1'],
                           ['2^(k-2)', '2k-2'],
                           ['Full factorial', 'fullFactorial'],
                           ['Fractional factorial (with Federov algorithm)', 'fractionalFactorial'],
                           ['Orthogonal Latin Hypercubes', 'latinHypercube'],
                       ])
  end

  def adapter_types
    options_for_select(%w(input_writer executor output_reader progress_monitor).map do |c|
        [ t("simulations.registration.#{c}"), c ]
      end
    )
  end

end
