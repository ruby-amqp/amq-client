# encoding: utf-8

require_relative "socket"

module AMQ
  class IoSelectClient < SyncClient
    def establish_connection(settings)
    end

    def disconnect
    end

    def send_raw(data)
    end
  end
end
