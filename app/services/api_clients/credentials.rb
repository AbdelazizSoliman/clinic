module ApiClients
  class Credentials
    Result = Data.define(:token, :plaintext)

    def self.issue!(api_client:, scopes:, actor: nil, expires_at: nil, action: "api_token_generated")
      token, plaintext = ApiToken.issue!(api_client:, scopes:, expires_at:)
      audit(api_client:, actor:, auditable: token, action:, metadata: { scopes: token.scopes, expires_at: token.expires_at })
      Result.new(token:, plaintext:)
    end

    def self.rotate!(token:, scopes: token.scopes, actor: nil, expires_at: token.expires_at)
      result = issue!(api_client: token.api_client, scopes:, actor:, expires_at:, action: "api_token_rotated")
      token.revoke!
      audit(api_client: token.api_client, actor:, auditable: token, action: "api_token_revoked", metadata: {})
      result
    end

    def self.revoke!(token:, actor: nil)
      token.revoke!
      audit(api_client: token.api_client, actor:, auditable: token, action: "api_token_revoked", metadata: {})
    end

    def self.audit(api_client:, actor:, auditable:, action:, metadata:)
      IntegrationAuditEvent.create!(organization: api_client.organization, api_client:, actor:, auditable:, action:, metadata:)
    end
    private_class_method :audit
  end
end
