require 'test_helper'
require 'mocha'

class InfrastructuresHelperTest < ActionView::TestCase

  def test_infrastructures_list_to_select_hash
    input = [
        {
            name: 'test1', children: [
              {
                  name: 'inner_test1',
                  infrastructure_name: 'inner_test1_id'
              }
            ]
        }
    ]

    output = Object.include(InfrastructuresHelper).infrastructures_list_to_select_data(input)

    assert_not_nil output, output
    assert_equal 1, input.count, output
    assert_equal 'test1', output[0][0], output
    assert_equal 'inner_test1', output[0][1][0][0]
    assert_equal input.first[:children].first[:infrastructure_name], output[0][1][0][1]
  end

end