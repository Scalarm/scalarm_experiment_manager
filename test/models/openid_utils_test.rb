require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'openid'
require 'openid/extensions/ax'
require 'openid_providers/openid_utils'

class OpemIDUtilsTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end

  def test_get_ax_attributes
    oidresp = mock 'oidresp'
    aliases = mock 'aliases'
    ax_resp = mock 'ax_resp' do
      stubs(:aliases).returns(aliases)
    end

    OpenID::AX::FetchResponse.stubs(:from_success_response).returns(ax_resp)

    custom_uri = 'http://custom.uri'
    attributes = [:city, :dn]
    aliases.expects(:add_alias).with(OpenIDUtils::AX_URI[:city], 'city').once
    aliases.expects(:add_alias).with(OpenIDUtils::AX_URI[:dn], 'dn').once
    values_hash = {
        'value.city' => 'Cracow',
        'value.dn' => 'someone'
    }
    result_hash = {
        city: 'Cracow',
        dn: 'someone'
    }
    ax_resp.expects(:get_extension_args).returns(values_hash).once

    result = OpenIDUtils.get_ax_attributes(oidresp, attributes)

    assert_equal result_hash, result
  end

end