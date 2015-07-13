require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class SimulationsControllerTest < ActionController::TestCase

  def setup
    stub_authentication
  end

  # test 'if result moe is not a string nor number it should to_s it' do
  #   SimulationsController.stubs(:load_simulation) do
  #     @simulation_run
  #   end
  #
  #   post :mark_as_complete, {
  #                         }
  # end

end
