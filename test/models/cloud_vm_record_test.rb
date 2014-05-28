require 'csv'
require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class CloudVmRecordTest < Test::Unit::TestCase

  def setup
  end

  def test_get_same_images_ids
    # given
    image1 = CloudImageSecrets.new({})
    image1.stubs(:id).returns(1)
    image1.stubs(:image_id).returns('i1')
    CloudImageSecrets.stubs(:find_by_id).with(1).returns(image1)

    image2 = CloudImageSecrets.new({})
    image2.stubs(:id).returns(2)
    image2.stubs(:image_id).returns('i1')
    CloudImageSecrets.stubs(:find_by_id).with(2).returns(image2)

    record1 = CloudVmRecord.new({'image_secrets_id'=> 1})
    record2 = CloudVmRecord.new({'image_secrets_id'=> 2})

    # when
    record1_secrets = record1.image_secrets
    record2_secrets = record2.image_secrets

    # then
    assert_equal record1_secrets.id, 1
    assert_equal record1_secrets.image_id, 'i1'
    assert_equal record2_secrets.id, 2
    assert_equal record2_secrets.image_id, 'i1'
  end

end