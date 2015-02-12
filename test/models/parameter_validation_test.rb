require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterValidationTest < MiniTest::Test

  class Dummy
    include ParameterValidation
  end

  def setup
    @dummy = Dummy.new
  end

  def test_single_param_validation_integer
    @dummy.single_param_validation('one', '1', :integer)
  end

  def test_single_param_validation_integer_fail
    assert_raises ParameterValidation::ValidationError do
      @dummy.single_param_validation('one', '1.0', [:integer])
    end
  end

  def test_single_param_validation_positive
    @dummy.single_param_validation('one', '1', [:integer, :positive])
  end

  def test_single_param_validation_positive_fail
    assert_raises ParameterValidation::ValidationError do
      @dummy.single_param_validation('one', '0', [:integer, :positive])
    end
  end


  def test_validate_params_ok_1
    params = {
        one: '1',
        two: '2',
        three: '3'
    }
    validators = {
        one: :integer,
        two: [:optional, :integer],
        three: [:validate_security_default, :integer],
        four: [:optional, :float]
    }

    @dummy.validate_params(params, validators)
  end

  def test_validate_params_fail_1
    params = {
        one: '1',
        two: '2.0'
    }
    validators = {
        one: :integer,
        two: [:optional, :integer]
    }

    assert_raises ParameterValidation::ValidationError do
      @dummy.validate_params(params, validators)
    end
  end

  def test_validate_params_fail_2
    params = {
        one: '1'
    }
    validators = {
        one: :integer,
        two: :integer
    }

    assert_raises ParameterValidation::MissingParametersError do
      @dummy.validate_params(params, validators)
    end
  end

end