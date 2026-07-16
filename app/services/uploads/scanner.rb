require "socket"
require "timeout"

module Uploads
  class Scanner
    class ConfigurationError < StandardError; end

    def self.call(blob)
      adapter.scan(blob)
    end

    def self.adapter
      case ENV.fetch("MALWARE_SCANNER_ADAPTER", Rails.env.production? ? "unconfigured" : "clean")
      when "clean" then CleanAdapter.new
      when "clamav" then ClamavAdapter.new(host: ENV.fetch("CLAMAV_HOST"), port: ENV.fetch("CLAMAV_PORT", 3310))
      else raise ConfigurationError, "A production malware scanner adapter is not configured"
      end
    end

    class CleanAdapter
      def scan(_blob) = :clean
    end

    class ClamavAdapter
      CHUNK_SIZE = 64.kilobytes

      def initialize(host:, port:, timeout: ENV.fetch("SCANNER_TIMEOUT_SECONDS", 10).to_f, socket_factory: Socket)
        @host, @port, @timeout, @socket_factory = host, Integer(port), timeout, socket_factory
      end

      def scan(blob)
        socket = @socket_factory.tcp(@host, @port, connect_timeout: @timeout)
        begin
          socket.write("zINSTREAM\0")
          blob.open do |file|
            while (chunk = file.read(CHUNK_SIZE))
              socket.write([ chunk.bytesize ].pack("N"))
              socket.write(chunk)
            end
          end
          socket.write([ 0 ].pack("N"))
          response = Timeout.timeout(@timeout) { socket.gets("\0").to_s }
          return :clean if response.include?("OK")
          return :infected if response.include?("FOUND")
          raise ConfigurationError, "Malware scanner returned an invalid response"
        ensure
          socket.close
        end
      rescue SystemCallError, Timeout::Error => error
        raise ConfigurationError, "Malware scanner unavailable: #{error.class.name}"
      end
    end
  end
end
