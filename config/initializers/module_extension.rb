class Module

  def add_execution_time_logging(*method_names)
    method_names.each do |method_name|
      original_method = instance_method(method_name)
      define_method(method_name) do |*args,&blk|
        execution_start = Time.now
        result = original_method.bind(self).call(*args,&blk)
        execution_end = Time.now

        method_label = "#{method_name}(#{args.join(",").to_s[0..50]})"
        execution_time_in_ms = "%.2f" % ((execution_end - execution_start)*1000)
        Rails.logger.debug("EXECUTION OF '#{method_label}' TOOK #{execution_time_in_ms} [ms]")

        result
      end
    end
  end

end

module Mongo
  class Collection
    add_execution_time_logging :find, :find_one, :insert, :drop, :update, :count
  end
end
