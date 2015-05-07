ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  #ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  #fixtures :all

  # Add more helper methods to be used by all tests here...

  def use_custom_controller(controller, &block)
    old_controller = self.class.controller_class
    begin
      self.class.controller_class = controller
      yield
    ensure
      self.class.controller_class = old_controller
    end
  end

end

class MockCollection
  attr_accessor :records

  def initialize(records)
    @records = records
  end

  def <<(attributes)
    @records << attributes
  end

  def find(attributes)
    records.select do |r|
      attributes.all? {|key, value| r[key] == value}
    end
  end
end

class MockRecord
  require 'set'
  @@collection = MockCollection.new(Set.new)


  attr_reader :attributes

  def initialize(attributes)
    @attributes = attributes
  end

  def save
    @@collection << @attributes
  end

  def self.find_all_by_query(attributes)
    @@collection.find(attributes).map {|attr| MockRecord.new(attr)}
  end

  def self.collection
    @@collection
  end
end
