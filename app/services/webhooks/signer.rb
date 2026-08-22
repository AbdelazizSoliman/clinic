module Webhooks
  class Signer
    def self.call(secret:, timestamp:, delivery_id:, body:)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{delivery_id}.#{body}")
    end
  end
end
