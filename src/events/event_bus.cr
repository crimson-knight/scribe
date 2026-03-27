require "./events"

module Scribe::Events
  module EventBus
    alias Handler = Proc(EventData, Nil)

    @@handlers = Hash(String, Array(Handler)).new { |h, k| h[k] = [] of Handler }

    # Register a handler for an event
    def self.on(event : String, &block : EventData -> Nil)
      @@handlers[event] << block
    end

    # Emit an event, dispatching synchronously to all registered handlers
    def self.emit(event : String, data : EventData = EventData.new)
      if handlers = @@handlers[event]?
        handlers.each { |handler| handler.call(data) }
      end
    end

    # Clear all handlers
    def self.clear
      @@handlers.clear
    end

    # Clear handlers for a specific event
    def self.clear(event : String)
      @@handlers.delete(event)
    end

    # Check if any handlers are registered for an event
    def self.has_handlers?(event : String) : Bool
      @@handlers.has_key?(event) && !@@handlers[event].empty?
    end
  end
end
