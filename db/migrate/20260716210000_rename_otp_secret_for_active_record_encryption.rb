class RenameOtpSecretForActiveRecordEncryption < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :otp_secret_ciphertext, :otp_secret
  end
end
