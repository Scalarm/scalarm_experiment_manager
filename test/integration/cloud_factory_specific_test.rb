require 'test/unit'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/clouds/cloud_facade_factory'

require 'infrastructure_facades/clouds/providers/pl_cloud'
require 'infrastructure_facades/clouds/providers/amazon'
require 'infrastructure_facades/clouds/providers/google'

class CloudFactorySpecificTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  CLIENT_CLASSES = {
      'pl_cloud' => PLCloud::CloudClient,
      'amazon' => AmazonCloud::CloudClient,
      'google' => GoogleCloud::CloudClient,
  }

  def test_load_classes
    CLIENT_CLASSES.each do |name, value|
      assert_equal  value, CloudFacadeFactory.instance.client_class(name)
    end
  end

end
