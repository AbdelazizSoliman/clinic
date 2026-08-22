class AddApiIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :rate_limit_per_minute, null: false, default: 60
      t.timestamps
    end
    create_table :api_tokens do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :api_client, null: false, foreign_key: true
      t.string :token_prefix, null: false
      t.string :token_digest, null: false
      t.string :scopes, array: true, null: false, default: []
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, :token_prefix

    create_table :api_idempotency_records do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :api_client, null: false, foreign_key: true
      t.string :action, null: false
      t.string :key, null: false
      t.string :request_digest, null: false
      t.integer :response_status, null: false
      t.jsonb :response_body, null: false, default: {}
      t.timestamps
    end
    add_index :api_idempotency_records, %i[organization_id api_client_id action key], unique: true, name: :index_api_idempotency_identity

    create_table :webhook_endpoints do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :url, null: false
      t.string :subscribed_events, array: true, null: false, default: []
      t.string :secret_digest, null: false
      t.text :encrypted_secret, null: false
      t.boolean :active, null: false, default: true
      t.integer :failure_count, null: false, default: 0
      t.timestamps
    end
    create_table :webhook_deliveries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.string :delivery_id, null: false
      t.string :event_name, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.integer :response_status
      t.string :response_excerpt
      t.string :status, null: false, default: "pending"
      t.datetime :delivered_at
      t.datetime :failed_at
      t.timestamps
    end
    add_index :webhook_deliveries, :delivery_id, unique: true
  end
end
