require 'test_helper'
require 'mocha'

class InfrastructuresHelperTest < ActionView::TestCase

  def test_infrastructures_list_to_select_hash
    input = [
        {
            name: 'test1', children: [
              {
                  name: 'inner_test1',
                  infrastructure_name: 'inner_test1_id',
                  infrastructure_params: {scheduler_type: 'x'}
              }
            ]
        }
    ]

    output = Object.include(InfrastructuresHelper).infrastructures_list_to_select_hash(input)

    assert_equal 1, input.count
    assert_equal 'test1', output[0][0]
    assert_equal 'inner_test1', output[0][1][0][0]
    assert_equal input.first[:children].first.to_json, output[0][1][0][1]
  end

end