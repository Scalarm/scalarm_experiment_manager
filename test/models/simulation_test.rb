require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class SimulationTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
    @simulation = Simulation.new({})
  end


  def test_input_specification
    json_record = Simulation.new({})
    json_record.expects(:get_attribute).with('input_specification').returns({"a" => 1})

    string_record = Simulation.new({})
    string_record.expects(:get_attribute).with('input_specification').returns('{"b":2}')

    soj_json = json_record.input_specification
    soj_string = string_record.input_specification

    assert_equal({"a" => 1}, soj_json)
    assert_equal({"b" => 2}, soj_string)
  end

  def test_missing_mandatory_adapter
    assert_raises MissingAdapterError do
      @simulation.set_up_adapter('adapter', nil, {})
    end
  end

  def test_missing_non_mandatory_adapter
    @simulation.set_up_adapter('adapter', nil, {}, false)
  end

  def test_mandatory_adapter_not_registered
    adapter_id = 'id'

    adapter_class = mock do
      expects(:find_by_id).with(adapter_id).returns(nil)
    end

    Object.expects(:const_get).with('SimulationAdapter').returns(adapter_class)

    assert_raises AdapterNotFoundError do
      @simulation.set_up_adapter('adapter', nil, {'adapter_id' => adapter_id})
    end
  end

  def test_non_mandatory_adapter_not_registered
    adapter_id = 'id'

    adapter_class = mock do
      expects(:find_by_id).with(adapter_id).returns(nil)
    end

    Object.expects(:const_get).with('SimulationAdapter').returns(adapter_class)

    @simulation.set_up_adapter('adapter', nil, {'adapter_id' => adapter_id}, false)
  end

  def test_mandatory_adapter_insecure_name
    insecure_name = '@#$%^&*'

    adapter_file = mock do
      expects(:original_filename).returns(insecure_name)
    end

    assert_raises SecurityError do
      @simulation.set_up_adapter('adapter', nil, {'adapter' => adapter_file})
    end
  end

  def test_non_mandatory_adapter_insecure_name
    insecure_name = '@#$%^&*'

    adapter_file = mock do
      expects(:original_filename).returns(insecure_name)
    end

    assert_raises SecurityError do
      @simulation.set_up_adapter('adapter', nil, {'adapter' => adapter_file}, false)
    end
  end

  def test_mandatory_adapter_secure_name
    secure_name = 'filename'
    code = 'code'
    user_id = 'user_id'
    adapter_id = 'adapter_id'

    user = mock do
      expects(:id).returns(user_id)
    end
    adapter_file = mock do
      expects(:original_filename).returns(secure_name)
    end
    adapter = mock do
      expects(:save)
      expects(:id).returns(adapter_id)
    end
    adapter_class = mock do
      expects(:new)
      .with({
                name: secure_name,
                code: code,
                user_id: user_id
            }).returns(adapter)
    end

    @simulation.expects(:adapter_id=).with(adapter_id)

    Object.expects(:const_get).with('SimulationAdapter').returns(adapter_class)
    Utils.expects(:read_if_file).with(adapter_file).returns(code)

    @simulation.set_up_adapter('adapter', user, {'adapter' => adapter_file})
  end

  def test_non_mandatory_adapter_secure_name
    secure_name = 'filename'
    code = 'code'
    user_id = 'user_id'
    adapter_id = 'adapter_id'

    user = mock do
      expects(:id).returns(user_id)
    end
    adapter_file = mock do
      expects(:original_filename).returns(secure_name)
    end
    adapter = mock do
      expects(:save)
      expects(:id).returns(adapter_id)
    end
    adapter_class = mock do
      expects(:new)
      .with({
            name: secure_name,
            code: code,
            user_id: user_id
      }).returns(adapter)
    end

    @simulation.expects(:adapter_id=).with(adapter_id)

    Object.expects(:const_get).with('SimulationAdapter').returns(adapter_class)
    Utils.expects(:read_if_file).with(adapter_file).returns(code)

    @simulation.set_up_adapter('adapter', user, {'adapter' => adapter_file}, false)
  end

  def test_mandatory_adapter_registered
    user_id = 'user_id'
    adapter_id = 'adapter_id'

    user = mock do
      expects(:id).returns(user_id)
    end
    adapter = mock do
      expects(:user_id).returns(user_id)
      expects(:id).returns(adapter_id)
    end
    adapter_class = mock do
      expects(:find_by_id).with(adapter_id).returns(adapter)
    end

    @simulation.expects(:adapter_id=).with(adapter_id)

    Object.expects(:const_get).with('SimulationAdapter').returns(adapter_class)

    @simulation.set_up_adapter('adapter', user, {'adapter_id' => adapter_id})
  end

  def test_non_mandatory_adapter_registered
    user_id = 'user_id'
    adapter_id = 'adapter_id'

    user = mock do
      expects(:id).returns(user_id)
    end
    adapter = mock do
      expects(:user_id).returns(user_id)
      expects(:id).returns(adapter_id)
    end
    adapter_class = mock do
      expects(:find_by_id).with(adapter_id).returns(adapter)
    end

    @simulation.expects(:adapter_id=).with(adapter_id)

    Object.expects(:const_get).with('SimulationAdapter').returns(adapter_class)

    @simulation.set_up_adapter('adapter', user, {'adapter_id' => adapter_id}, false)
  end
end