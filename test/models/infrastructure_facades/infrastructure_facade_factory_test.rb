require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructureFacadeTest < MiniTest::Test

  def test_get_facade_for_fail
    assert_raises InfrastructureErrors::NoSuchInfrastructureError do
      InfrastructureFacadeFactory.get_facade_for('something_new')
    end

    assert_raises InfrastructureErrors::NoSuchInfrastructureError do
      InfrastructureFacadeFactory.get_facade_for(nil)
    end
  end

  def test_get_all_sm_records
    f1_r1 = mock 'f1_r1'
    f1_r2 = mock 'f1_r2'
    f2_r1 = mock 'f2_r1'
    f2_r2 = mock 'f2_r2'

    f1_records = [f1_r1, f1_r2]
    f2_records = [f2_r1, f2_r2]

    user_id = mock 'user_id'
    experiment_id = mock 'experiment_id'
    params = mock 'params'

    f1 = mock 'facade1' do
      stubs(:get_sm_records).with(user_id, experiment_id, params).returns(f1_records)
    end
    f2 = mock 'facade2' do
      stubs(:get_sm_records).with(user_id, experiment_id, params).returns(f2_records)
    end

    InfrastructureFacadeFactory.stubs(:get_all_infrastructures).returns([f1, f2])

    all_records = InfrastructureFacadeFactory.get_all_sm_records(user_id, experiment_id, params)

    (f1_records + f2_records).each do |r|
      assert_includes all_records, r
    end
  end

end