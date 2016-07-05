require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ClusterFacadeTest < MiniTest::Test

  def setup
    @scheduler = mock()
    @cluster_record = mock()
    @cluster_record.stubs(:id).returns('id')
    @cluster_record.stubs(:name).returns('Great clusters')

    @facade = ClusterFacade.new(@cluster_record, @scheduler)
  end

  def test_names_without_cluster_record
    facade = ClusterFacade.new(nil, @scheduler)

    assert_equal 'clusters', facade.short_name
    assert_equal 'clusters', facade.long_name
  end

  def test_names_with_cluster_record
    assert_equal 'cluster_id', @facade.short_name
    assert_equal 'Great clusters', @facade.long_name
  end

end

