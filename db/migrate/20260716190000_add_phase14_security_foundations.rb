class AddPhase14SecurityFoundations < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.text :otp_secret_ciphertext
      t.datetime :otp_enabled_at
      t.jsonb :recovery_code_digests, null: false, default: []
      t.bigint :last_otp_timestep
    end

    create_table :security_events do |t|
      t.references :user, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.string :ip_digest
      t.string :user_agent_summary, limit: 200
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
      t.index %i[event_type created_at]
    end

    create_table :job_heartbeats do |t|
      t.string :job_name, null: false
      t.datetime :last_started_at
      t.datetime :last_succeeded_at
      t.datetime :last_failed_at
      t.string :failure_class
      t.integer :duration_ms
      t.integer :processed_count
      t.timestamps
      t.index :job_name, unique: true
    end
  end
end
