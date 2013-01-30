require 'test_helper'

class ExperimentTest < ActiveSupport::TestCase

  test "instances partitioning" do
    experiment = Experiment.new

# very small experiment partitioning - less than 1000 instances
    partitions = experiment.instances_partitioning(3, 4)
    assert_equal partitions.size, 1
    assert_equal partitions[0], { :start_id => 1, :end_id => 3, :db_index => 0 }


# normal experiment partitioning - between 1000 and 100k instances
    partitions = experiment.instances_partitioning(7776, 2)
    assert_equal partitions.size, 2
    assert_equal partitions[0], { :start_id => 1, :end_id => 3888, :db_index => 0 }
    assert_equal partitions[1], { :start_id => 3889, :end_id => 7776, :db_index => 1 }


# large experiment partitioning - more than 100k instances
    partitions = experiment.instances_partitioning(7776837, 15)
    assert_equal partitions.size, 78
    db_index = 0
    0.upto(77) do |partition_counter|
      if partition_counter == 77
        assert_equal(partitions[partition_counter],
        { :start_id => partition_counter * 100000 + 1,
          :end_id => 7776837, :db_index => partition_counter % 15 } )
      else
        assert_equal(partitions[partition_counter],
          { :start_id => partition_counter * 100000 + 1,
            :end_id => (partition_counter + 1) * 100000, :db_index => partition_counter % 15 } )
      end
    end

  end
end
