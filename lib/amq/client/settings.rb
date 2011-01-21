# encoding: utf-8

module AMQ
  module Client
    module Settings
      def default
        @default ||= {
          # server
          :host  => "127.0.0.1",
          :port  => AMQ::Protocol::DEFAULT_PORT,

          # login
          :user  => "guest",
          :pass  => "guest",
          :vhost => "/",

          # connection timeout
          :timeout => nil,

          # logging
          :logging => false,

          # ssl
          :ssl => false
        }
      end
    end

    def configure(settings)
      @settings ||= self.default.merge(settings)
    end
  end
end
