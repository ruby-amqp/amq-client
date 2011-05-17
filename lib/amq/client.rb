# encoding: utf-8

require "amq/client/version"
require "amq/client/exceptions"
require "amq/client/handlers_registry"
require "amq/client/adapter"
require "amq/client/channel"
require "amq/client/exchange"
require "amq/client/queue"

begin
  require "amq/protocol/client"
rescue LoadError => exception
  if exception.message.match("amq/protocol")
    raise LoadError.new("You have to install amq-protocol library first!")
  else
    raise exception
  end
end

module AMQ
  module Client
    # List all the available as a hash of {adapter_name: metadata},
    # where metadata are hash with :path and :const_name keys.
    #
    # @example
    #   AMQ::Client.adapters[:event_machine] # => {path: "...", const_name: "EventMachineClient"}}
    #
    # @return [Hash]
    # @api public
    def self.adapters
      @adapters ||= begin
        root = File.expand_path("../client/adapters", __FILE__)
        Dir.glob("#{root}/*.rb").inject(Hash.new) do |buffer, path|
          name = path.match(/([^\/]+)\.rb$/)[1]
          const_base = name.to_s.gsub(/(^|_)(.)/) { $2.upcase! }
          meta = {:path => path, :const_name => "#{const_base}Client"}
          buffer.merge!(name.to_sym => meta)
        end
      end
    end

    # Establishes connection to AMQ broker using given adapter
    # (defaults to the socket adapter) and returns it. The new
    # connection object is yielded to the block if it is given.
    #
    # @example
    #   AMQ::Client.connect(adapter: "socket") do |client|
    #     # Use the client.
    #   end
    # @param [Hash] Connection parameters, including :adapter to use.
    # @api public
    def self.connect(settings = nil, &block)
      adapter  = (settings && settings.delete(:adapter))
      adapter  = load_adapter(adapter)
      adapter.connect(settings, &block)
    end

    # Loads adapter from amq/client/adapters.
    #
    # @raise [InvalidAdapterNameError] When loading attempt failed (LoadError was raised).
    def self.load_adapter(adapter)
      meta = self.adapters[adapter.to_sym]

      require meta[:path]
      const_get(meta[:const_name])
    rescue LoadError
      raise InvalidAdapterNameError.new(adapter)
    end
  end # Client
end # AMQ
