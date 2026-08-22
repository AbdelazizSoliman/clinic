require "ipaddr"
require "resolv"
require "timeout"

module Webhooks
  class UrlPolicy
    class UnsafeUrl < StandardError; end
    BLOCKED = [ IPAddr.new("0.0.0.0/8"), IPAddr.new("10.0.0.0/8"), IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"), IPAddr.new("172.16.0.0/12"), IPAddr.new("192.168.0.0/16"),
      IPAddr.new("::1/128"), IPAddr.new("fc00::/7"), IPAddr.new("fe80::/10") ].freeze

    def self.validate!(value)
      uri = URI.parse(value.to_s)
      raise UnsafeUrl, "يجب استخدام HTTPS" unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
      host = uri.host.delete_prefix("[").delete_suffix("]")
      raise UnsafeUrl, "العنوان الداخلي غير مسموح" if host == "localhost" || host.end_with?(".localhost")
      addresses = begin
        [ IPAddr.new(host).to_s ]
      rescue IPAddr::InvalidAddressError
        Timeout.timeout(2) { Resolv.getaddresses(host) }
      end
      raise UnsafeUrl, "تعذر التحقق من المضيف" if addresses.empty?
      raise UnsafeUrl, "العنوان الداخلي غير مسموح" if addresses.any? { |address| BLOCKED.any? { |range| range.include?(IPAddr.new(address)) } }
      true
    rescue URI::InvalidURIError, Resolv::ResolvError, IPAddr::InvalidAddressError, Timeout::Error
      raise UnsafeUrl, "عنوان webhook غير صالح"
    end
  end
end
