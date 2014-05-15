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

    output = Object.include(InfrastructuresHelper).infrastructures_list_to_select_data(input)

    assert_equal 1, input.count
    assert_equal 'test1', output[0][0]
    assert_equal 'inner_test1', output[0][1][0][0]
    assert_equal input.first[:children].first.to_json, output[0][1][0][1]
  end

  def test_find_infrastructures_data_value
    value_to_select = '{"name":"PBS","infrastructure_name":"plgrid","infrastructure_params":{"scheduler_type":"qsub"}}'

    select_data = [
        ['A', [['a', {'infrastructure_name'=>'a_inf'}.to_json], ['b', {'infrastructure_name'=>'b_inf'}.to_json]]],
        ['B', [['c', {'infrastructure_name'=>'c_inf'}.to_json], ['zxc', value_to_select.clone]]],
        ['C', [['d', {'infrastructure_name'=>'d_inf'}.to_json], ['e', {'infrastructure_name'=>'e_inf'}.to_json]]]
    ]

    assert_equal value_to_select, find_infrastructures_data_value(select_data, 'plgrid')
  end

end