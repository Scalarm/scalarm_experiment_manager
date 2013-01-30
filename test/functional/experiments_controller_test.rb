require 'test_helper'

class ExperimentsControllerTest < ActionController::TestCase
  @@params_hash = {"Agent_2_sympathy_othergroup_variance_value"=>"50.0",
    "Agent_2_membership_feeling_samegroup_variance_value"=>"50.0",
    "Agent_4_PC_FearDec_variance_value"=>"50.0",
    "Agent_4_sympathy_othergroup_variance_value"=>"50.0",
    "Agent_4_membership_feeling_samegroup_variance_value"=>"50.0",
    "Agent_6_PC_FearInc_variance_value"=>"0.5",
    "Agent_4_agent_prestige_variance_value"=>"50.0",
    "Agent_2_agent_prestige_mean_value"=>"50.0",
    "Agent_3_membership_feeling_samegroup_mean_value"=>"50.0",
    "Agent_6_PC_FearDec_variance_value"=>"0.5",
    "Agent_1_sympathy_othergroup_variance_value"=>"50.0",
    "Agent_1_sympathy_othergroup_mean_value"=>"50.0",
    "Agent_8_PC_FearInc_variance_value"=>"0.5",
    "Agent_9_PC_FearInc_variance_value"=>"0.5",
    "Agent_5_PC_FearDec_mean_value"=>"0.5",
    "Agent_4_agent_prestige_mean_value"=>"50.0",
    "Agent_11_PC_FearInc_variance_value"=>"0.5",
    "Agent_4_membership_feeling_samegroup_mean_value"=>"50.0",
    "Agent_9_PC_FearDec_variance_value"=>"0.5",
    "Agent_13_PC_FearInc_mean_value"=>"0.5",
    "Agent_12_PC_FearDec_variance_value"=>"0.5",
    "Agent_5_PC_FearInc_variance_value"=>"0.5",
    "Agent_2_sympathy_othergroup_mean_value"=>"50.0",
    "Agent_3_sympathy_othergroup_variance_value"=>"50.0",
    "Agent_9_PC_FearInc_mean_value"=>"0.5",
    "Agent_11_PC_FearInc_mean_value"=>"0.5",
    "Agent_4_PC_FearInc_variance_value"=>"50.0",
    "Agent_5_PC_FearInc_mean_value"=>"0.5",
    "Agent_3_membership_feeling_samegroup_variance_value"=>"50.0",
    "utf8"=>"\342\234\223",
    "Agent_11_PC_FearDec_mean_value"=>"0.5",
    "Agent_3_agent_prestige_variance_value"=>"50.0",
    "Agent_7_PC_FearInc_variance_value"=>"0.5",
    "Agent_13_PC_FearDec_mean_value"=>"0.5",
    "Agent_4_sympathy_othergroup_mean_value"=>"50.0",
    "Agent_7_PC_FearDec_mean_value"=>"0.5",
    "Agent_5_PC_FearDec_variance_value"=>"0.5",
    "Agent_10_MinDistance_mean_value"=>"0.5",
    "Agent_7_PC_FearInc_mean_value"=>"0.5",
    "Agent_9_PC_FearDec_mean_value"=>"0.5",
    "Agent_8_PC_FearDec_variance_value"=>"0.5",
    "Agent_10_PC_FearInc_mean_value"=>"0.5",
    "Agent_3_sympathy_othergroup_mean_value"=>"50.0",
    "Agent_10_PC_FearInc_variance_value"=>"0.5",
    "Agent_11_PC_FearDec_variance_value"=>"0.5",
    "Agent_7_PC_FearDec_variance_value"=>"0.5",
    "Agent_10_PC_FearDec_mean_value"=>"0.5",
    "Agent_12_PC_FearInc_mean_value"=>"0.5",
    "Agent_2_membership_feeling_samegroup_mean_value"=>"50.0",
    "Agent_6_PC_FearInc_mean_value"=>"0.5",
    "Agent_10_PC_FearDec_variance_value"=>"0.5",
    "Agent_3_agent_prestige_mean_value"=>"50.0",
    "Agent_10_MinDistance_variance_value"=>"0.5",
    "Agent_12_PC_FearDec_mean_value"=>"0.5",
    "commit"=>"Run Data Farming experiment",
    "Agent_13_PC_FearInc_variance_value"=>"0.5",
    "Agent_6_PC_FearDec_mean_value"=>"0.5",
    "Agent_13_PC_FearDec_variance_value"=>"0.5",
    "Agent_12_PC_FearInc_variance_value"=>"0.5",
    "Agent_4_PC_FearInc_mean_value"=>"50.0",
    "Agent_8_PC_FearInc_mean_value"=>"0.5",
    "Agent_2_agent_prestige_variance_value"=>"50.0",
    "Agent_8_PC_FearDec_mean_value"=>"0.5",
    "Agent_4_PC_FearDec_mean_value"=>"50.0"
  }

  test "should post configuration done" do
    @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("eusas:change.ME")
    doe_values = { "instance_id" => 1, "instance_result" => "moe1=1,moe2=2"}
    
    post :set_configuration_done, doe_values
    
    ei = ExperimentInstance.find_by_id(1)
    assert_equal("moe1=1.0000,moe2=2.0000", ei.result)
  end
  
  # test "should get start fullFactorial" do
  #     @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("eusas:change.ME")
  #     
  #     doe_params_hash = {
  #       "experiment_id"=>"1",
  #       "doe_type"=>"fullFactorial",
  #       "doe_fullFactorial_0_params"=>"Agent_1_agent_prestige,Agent_1_membership_feeling_samegroup",
  #       "doe_fullFactorial_0_opts"=>",",
  #       "Agent_1_agent_prestige_min"=>"0.0",
  #       "Agent_1_agent_prestige_max"=>"100.0",
  #       "Agent_1_agent_prestige_step"=>"30.0",
  #       "Agent_1_membership_feeling_samegroup_min"=>"0.0",
  #       "Agent_1_membership_feeling_samegroup_max"=>"100.0",
  #       "Agent_1_membership_feeling_samegroup_step"=>"30.0"
  #     }
  #     
  #     get :start, @@params_hash.merge(doe_params_hash)
  #     experiment = Experiment.find_by_id(1)
  #     assert_equal(16, experiment.experiment_size)
  #     assert_response 302
  #   end
  #   
  #   test "should get start 2k" do
  #     @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("eusas:change.ME")
  #     
  #     doe_params_hash = {
  #       "experiment_id"=>"2",
  #       "doe_type"=>"2k",
  #       "doe_2k_0_params"=>"Agent_1_agent_prestige,Agent_1_membership_feeling_samegroup",
  #       "doe_2k_0_opts"=>",",
  #       "Agent_1_agent_prestige_min"=>"0.0",
  #       "Agent_1_agent_prestige_max"=>"100.0",
  #       "Agent_1_agent_prestige_step"=>"30.0",
  #       "Agent_1_membership_feeling_samegroup_min"=>"0.0",
  #       "Agent_1_membership_feeling_samegroup_max"=>"100.0",
  #       "Agent_1_membership_feeling_samegroup_step"=>"30.0"
  #     }
  #     
  #     get :start, @@params_hash.merge(doe_params_hash)
  #     experiment = Experiment.find_by_id(2)
  #     assert_equal(4, experiment.experiment_size)
  #     assert_response 302
  #   end

end
