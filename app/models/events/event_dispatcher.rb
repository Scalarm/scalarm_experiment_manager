require_relative 'system_event'

class EventDispatcher
  LOOP_INTERVAL = 10

  def initialize
    @listeners = {}
    @last_event_id = nil
  end

  def add_listener(event_type, listener)
    @listeners[event_type] = [] unless @listeners.include?(event_type)

    @listeners[event_type] << listener
  end

  def start_dispatching_loop

    Thread.new do
      while true
        dispatch

        sleep(LOOP_INTERVAL)
      end
    end

  end

  def dispatch
    query = @last_event_id.nil? ? {  } : { '_id' => { '$gt' => @last_event_id } }
    events = SystemEvent.where(query, { :sort => [ [ '_id', 'desc' ] ] })
    p "Event count: #{events.size}"

    events.each do |event|
      unless @listeners[event.type].nil?

        @listeners[event.type].each do |listener|

          begin
            Thread.new do
              listener.send(:execute, event)
            end
          rescue Exception => e
            Rails.logger.error("Exception during event handling: #{event.inspect} --- #{listener.inspect}")
          end
        end
      end


      @last_event_id = event.id
      event.destroy
    end

  end

end